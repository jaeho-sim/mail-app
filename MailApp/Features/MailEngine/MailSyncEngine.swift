//
//  MailSyncEngine.swift
//  MailApp
//
//  Orchestrates fetching from Gmail and upserting into the local SwiftData store.
//  Operates per-account (multi-account support) with a helper to sync all
//  connected accounts at once for the unified inbox / periodic refresh.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class MailSyncEngine: ObservableObject {
    static let shared = MailSyncEngine()

    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var lastSyncedAt: Date?
    @Published private(set) var nextPageTokens: [String: String] = [:] // keyed by accountEmail

    private let client = GmailAPIClient()
    private let pageSize = 25

    private init() {}

    func nextPageToken(forAccountEmail email: String) -> String? {
        nextPageTokens[email]
    }

    /// Syncs one connected account: its labels (as mailboxes) and the first page of inbox messages.
    func syncAccount(accountEmail: String, accessToken: String, modelContext: ModelContext) async {
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }

        do {
            let labelsResponse = try await client.listLabels(accessToken: accessToken)
            let keptLabels = labelsResponse.labels.filter(Self.isSidebarWorthy)
            for label in keptLabels {
                upsertMailbox(name: label.name, accountEmail: accountEmail, modelContext: modelContext)
            }
            removeStaleMailboxes(keeping: keptLabels.map(\.name), accountEmail: accountEmail, modelContext: modelContext)

            let listResponse = try await client.listMessages(labelId: "INBOX", maxResults: pageSize, accessToken: accessToken)
            for ref in listResponse.messages ?? [] {
                let full = try await client.getMessage(id: ref.id, accessToken: accessToken)
                upsertMessage(full, accountEmail: accountEmail, modelContext: modelContext)
            }

            // Flagged mail can live anywhere (archived, sent, etc.), not just the
            // Inbox — fetch by the STARRED label directly so the Flagged smart
            // mailbox reflects everything flagged, not just what's in the inbox.
            let starredListResponse = try await client.listMessages(labelId: "STARRED", maxResults: pageSize, accessToken: accessToken)
            for ref in starredListResponse.messages ?? [] {
                let full = try await client.getMessage(id: ref.id, accessToken: accessToken)
                upsertMessage(full, accountEmail: accountEmail, modelContext: modelContext)
            }

            try modelContext.save()
            nextPageTokens[accountEmail] = listResponse.nextPageToken
            lastSyncedAt = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Syncs every connected account in turn. Used for the unified inbox and periodic refresh.
    func syncAllAccounts(_ accounts: [Account], modelContext: ModelContext) async {
        for account in accounts {
            guard let token = try? await AccountsManager.shared.accessToken(forAccountEmail: account.email) else {
                continue
            }
            await syncAccount(accountEmail: account.email, accessToken: token, modelContext: modelContext)
        }
    }

    /// Fetches the next page of older inbox messages for one account (pagination).
    func loadMoreMessages(accountEmail: String, accessToken: String, modelContext: ModelContext) async {
        guard let pageToken = nextPageTokens[accountEmail] else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }

        do {
            let listResponse = try await client.listMessages(
                labelId: "INBOX",
                maxResults: pageSize,
                pageToken: pageToken,
                accessToken: accessToken
            )
            for ref in listResponse.messages ?? [] {
                let full = try await client.getMessage(id: ref.id, accessToken: accessToken)
                upsertMessage(full, accountEmail: accountEmail, modelContext: modelContext)
            }
            try modelContext.save()
            nextPageTokens[accountEmail] = listResponse.nextPageToken
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Gmail returns every system label (STARRED, IMPORTANT, UNREAD, the inbox
    /// tab categories, CHAT, etc.) alongside real folders. Only the traditional
    /// mailbox-style system labels and genuine user-created labels belong in
    /// the sidebar as "folders" — the rest are either handled elsewhere
    /// (STARRED → the Flagged smart mailbox) or not useful as a folder at all.
    private static let sidebarSystemLabelNames: Set<String> = ["INBOX", "SENT", "DRAFT", "TRASH", "SPAM"]

    private static func isSidebarWorthy(_ label: GmailLabel) -> Bool {
        label.type == "user" || sidebarSystemLabelNames.contains(label.name.uppercased())
    }

    private func upsertMailbox(name: String, accountEmail: String, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Mailbox>(
            predicate: #Predicate { $0.name == name && $0.accountEmail == accountEmail }
        )
        if (try? modelContext.fetch(descriptor).first) != nil {
            return
        }
        modelContext.insert(Mailbox(name: name, accountEmail: accountEmail))
    }

    /// Removes previously-synced mailboxes that are no longer sidebar-worthy
    /// (e.g. from before this filter existed, or a label the user deleted).
    private func removeStaleMailboxes(keeping names: [String], accountEmail: String, modelContext: ModelContext) {
        let keepSet = Set(names)
        let descriptor = FetchDescriptor<Mailbox>(predicate: #Predicate { $0.accountEmail == accountEmail })
        guard let existing = try? modelContext.fetch(descriptor) else { return }
        for mailbox in existing where !keepSet.contains(mailbox.name) {
            modelContext.delete(mailbox)
        }
    }

    private func upsertMessage(_ gmailMessage: GmailMessage, accountEmail: String, modelContext: ModelContext) {
        let id = gmailMessage.id
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.messageId == id })

        let headers = gmailMessage.payload?.headers ?? []
        let subject = headers.first { $0.name.caseInsensitiveCompare("Subject") == .orderedSame }?.value ?? "(no subject)"
        let sender = headers.first { $0.name.caseInsensitiveCompare("From") == .orderedSame }?.value ?? "Unknown sender"
        let isRead = !(gmailMessage.labelIds?.contains("UNREAD") ?? false)
        let isFlagged = gmailMessage.labelIds?.contains("STARRED") ?? false
        let receivedAt = Self.date(fromInternalDate: gmailMessage.internalDate) ?? .now
        let mailboxName = Self.primaryMailboxName(for: gmailMessage.labelIds)

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.subject = subject
            existing.sender = sender
            existing.snippet = gmailMessage.snippet ?? ""
            existing.isRead = isRead
            existing.isFlagged = isFlagged
            existing.receivedAt = receivedAt
            existing.accountEmail = accountEmail
            existing.mailboxName = mailboxName
            return
        }

        modelContext.insert(
            Message(
                messageId: id,
                subject: subject,
                sender: sender,
                snippet: gmailMessage.snippet ?? "",
                receivedAt: receivedAt,
                isRead: isRead,
                mailboxName: mailboxName,
                accountEmail: accountEmail,
                isFlagged: isFlagged
            )
        )
    }

    /// Determines which "folder" a message belongs to from its actual labels,
    /// rather than assuming INBOX — a flagged message might be archived, sent,
    /// etc. "ARCHIVE" is a synthetic bucket (not a real Gmail label) for mail
    /// that isn't in any of the traditional mailboxes.
    private static func primaryMailboxName(for labelIds: [String]?) -> String {
        let labels = Set(labelIds ?? [])
        if labels.contains("INBOX") { return "INBOX" }
        if labels.contains("SENT") { return "SENT" }
        if labels.contains("DRAFT") { return "DRAFT" }
        if labels.contains("TRASH") { return "TRASH" }
        if labels.contains("SPAM") { return "SPAM" }
        return "ARCHIVE"
    }

    private static func date(fromInternalDate value: String?) -> Date? {
        guard let value, let millis = Double(value) else { return nil }
        return Date(timeIntervalSince1970: millis / 1000)
    }
}
