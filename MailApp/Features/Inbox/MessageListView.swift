//
//  MessageListView.swift
//  MailApp
//
//  The message list column (middle pane in the 3-pane layout). Supports the
//  unified inbox or a single account+mailbox, search, and swipe actions.
//

import SwiftUI
import SwiftData

struct MessageListView: View {
    @Query private var messages: [Message]
    @Binding var selection: String?

    let mailboxSelection: MailboxSelection

    @State private var searchText = ""
    @StateObject private var mailSync = MailSyncEngine.shared
    @Environment(\.modelContext) private var modelContext

    init(mailboxSelection: MailboxSelection, selection: Binding<String?>) {
        self.mailboxSelection = mailboxSelection
        switch mailboxSelection {
        case .unified:
            _messages = Query(
                filter: #Predicate<Message> { $0.mailboxName == "INBOX" },
                sort: [SortDescriptor(\Message.receivedAt, order: .reverse)]
            )
        case .flagged:
            _messages = Query(
                filter: #Predicate<Message> { $0.isFlagged == true },
                sort: [SortDescriptor(\Message.receivedAt, order: .reverse)]
            )
        case .account(let email, let mailboxName):
            _messages = Query(
                filter: #Predicate<Message> { $0.accountEmail == email && $0.mailboxName == mailboxName },
                sort: [SortDescriptor(\Message.receivedAt, order: .reverse)]
            )
        }
        _selection = selection
    }

    private var filteredMessages: [Message] {
        guard !searchText.isEmpty else { return messages }
        let needle = searchText.lowercased()
        return messages.filter {
            $0.subject.lowercased().contains(needle) ||
            $0.sender.lowercased().contains(needle) ||
            $0.snippet.lowercased().contains(needle)
        }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(filteredMessages, id: \.messageId) { message in
                MessageRow(message: message)
                    .tag(message.messageId)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(message)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            archive(message)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                        .tint(.orange)
                        Button {
                            toggleFlag(message)
                        } label: {
                            Label(
                                message.isFlagged ? "Unflag" : "Flag",
                                systemImage: message.isFlagged ? "flag.slash" : "flag"
                            )
                        }
                        .tint(.yellow)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleRead(message)
                        } label: {
                            Label(
                                message.isRead ? "Unread" : "Read",
                                systemImage: message.isRead ? "envelope.badge" : "envelope.open"
                            )
                        }
                        .tint(.blue)
                    }
            }

            if case .account(let email, _) = mailboxSelection, mailSync.nextPageToken(forAccountEmail: email) != nil {
                HStack {
                    Spacer()
                    if mailSync.isSyncing {
                        ProgressView()
                    } else {
                        Button("Load More") {
                            Task { await loadMore(accountEmail: email) }
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Search Mail")
        .overlay {
            if filteredMessages.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Messages" : "No Results",
                    systemImage: searchText.isEmpty ? "tray" : "magnifyingglass"
                )
            }
        }
    }

    private func loadMore(accountEmail: String) async {
        guard let token = try? await AccountsManager.shared.accessToken(forAccountEmail: accountEmail) else { return }
        await mailSync.loadMoreMessages(accountEmail: accountEmail, accessToken: token, modelContext: modelContext)
    }

    // Local (SwiftData) mutations happen synchronously, before any `await` —
    // that's what keeps List's diffing sane. The Gmail API call runs afterward
    // in the background; on failure it's reported via mailSync.errorMessage
    // rather than rolled back (a stale local flag/delete is a much smaller
    // problem than a crash, and the next sync reconciles it either way).

    private func toggleRead(_ message: Message) {
        let wasRead = message.isRead
        let accountEmail = message.accountEmail
        let messageId = message.messageId

        withAnimation {
            message.isRead.toggle()
            try? modelContext.save()
        }

        Task {
            guard let token = try? await AccountsManager.shared.accessToken(forAccountEmail: accountEmail) else { return }
            do {
                if wasRead {
                    try await GmailAPIClient().modifyMessage(id: messageId, addLabelIds: ["UNREAD"], accessToken: token)
                } else {
                    try await GmailAPIClient().modifyMessage(id: messageId, removeLabelIds: ["UNREAD"], accessToken: token)
                }
            } catch {
                mailSync.errorMessage = error.localizedDescription
            }
        }
    }

    private func archive(_ message: Message) {
        let accountEmail = message.accountEmail
        let messageId = message.messageId

        withAnimation {
            modelContext.delete(message)
            try? modelContext.save()
        }

        Task {
            guard let token = try? await AccountsManager.shared.accessToken(forAccountEmail: accountEmail) else { return }
            do {
                try await GmailAPIClient().modifyMessage(id: messageId, removeLabelIds: ["INBOX"], accessToken: token)
            } catch {
                mailSync.errorMessage = error.localizedDescription
            }
        }
    }

    private func delete(_ message: Message) {
        let accountEmail = message.accountEmail
        let messageId = message.messageId

        withAnimation {
            modelContext.delete(message)
            try? modelContext.save()
        }

        Task {
            guard let token = try? await AccountsManager.shared.accessToken(forAccountEmail: accountEmail) else { return }
            do {
                try await GmailAPIClient().trashMessage(id: messageId, accessToken: token)
            } catch {
                mailSync.errorMessage = error.localizedDescription
            }
        }
    }

    /// Toggles Gmail's STARRED label — the same label Apple Mail's flag
    /// (\Flagged over IMAP) maps to, so this stays in sync with native Mail.
    private func toggleFlag(_ message: Message) {
        let wasFlagged = message.isFlagged
        let accountEmail = message.accountEmail
        let messageId = message.messageId

        withAnimation {
            message.isFlagged.toggle()
            try? modelContext.save()
        }

        Task {
            guard let token = try? await AccountsManager.shared.accessToken(forAccountEmail: accountEmail) else { return }
            do {
                if wasFlagged {
                    try await GmailAPIClient().modifyMessage(id: messageId, removeLabelIds: ["STARRED"], accessToken: token)
                } else {
                    try await GmailAPIClient().modifyMessage(id: messageId, addLabelIds: ["STARRED"], accessToken: token)
                }
            } catch {
                mailSync.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(.tint.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(initials(for: message.sender))
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.sender)
                        .font(.subheadline)
                        .fontWeight(message.isRead ? .regular : .semibold)
                        .lineLimit(1)
                    if message.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Text(message.receivedAt, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(message.subject)
                    .font(.subheadline)
                    .fontWeight(message.isRead ? .regular : .semibold)
                    .lineLimit(1)
                Text(message.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(message.accountEmail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            if !message.isRead {
                Circle()
                    .fill(.tint)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func initials(for sender: String) -> String {
        let namePart = sender.split(separator: "<").first.map(String.init) ?? sender
        let parts = namePart.trimmingCharacters(in: .whitespaces).split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
