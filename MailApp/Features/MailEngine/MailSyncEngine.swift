//
//  MailSyncEngine.swift
//  MailApp
//
//  Orchestrates fetching from Gmail and upserting into the local SwiftData store.
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
    @Published private(set) var nextPageToken: String?

    private let client = GmailAPIClient()
    private let pageSize = 25

    private init() {}

    /// Fetches labels (as mailboxes) and the first page of inbox messages, upserting both into `modelContext`.
    func syncInbox(accountEmail: String, accessToken: String, modelContext: ModelContext) async {
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }

        do {
            let labelsResponse = try await client.listLabels(accessToken: accessToken)
            for label in labelsResponse.labels {
                upsertMailbox(name: label.name, accountEmail: accountEmail, modelContext: modelContext)
            }

            let listResponse = try await client.listMessages(labelId: "INBOX", maxResults: pageSize, accessToken: accessToken)
            for ref in listResponse.messages ?? [] {
                let full = try await client.getMessage(id: ref.id, accessToken: accessToken)
                upsertMessage(full, modelContext: modelContext)
            }

            try modelContext.save()
            nextPageToken = listResponse.nextPageToken
            lastSyncedAt = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches the next page of older inbox messages (pagination), if one exists.
    /// Call from a "Load More" affordance at the bottom of the message list.
    func loadMoreMessages(accessToken: String, modelContext: ModelContext) async {
        guard let pageToken = nextPageToken else { return }
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
                upsertMessage(full, modelContext: modelContext)
            }
            try modelContext.save()
            nextPageToken = listResponse.nextPageToken
        } catch {
            errorMessage = error.localizedDescription
        }
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

    private func upsertMessage(_ gmailMessage: GmailMessage, modelContext: ModelContext) {
        let id = gmailMessage.id
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.messageId == id })

        let headers = gmailMessage.payload?.headers ?? []
        let subject = headers.first { $0.name.caseInsensitiveCompare("Subject") == .orderedSame }?.value ?? "(no subject)"
        let sender = headers.first { $0.name.caseInsensitiveCompare("From") == .orderedSame }?.value ?? "Unknown sender"
        let isRead = !(gmailMessage.labelIds?.contains("UNREAD") ?? false)
        let receivedAt = Self.date(fromInternalDate: gmailMessage.internalDate) ?? .now

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.subject = subject
            existing.sender = sender
            existing.snippet = gmailMessage.snippet ?? ""
            existing.isRead = isRead
            existing.receivedAt = receivedAt
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
                mailboxName: "INBOX"
            )
        )
    }

    private static func date(fromInternalDate value: String?) -> Date? {
        guard let value, let millis = Double(value) else { return nil }
        return Date(timeIntervalSince1970: millis / 1000)
    }
}
