//
//  MessageListView.swift
//  MailApp
//
//  The message list column (middle pane in the 3-pane layout).
//

import SwiftUI
import SwiftData

struct MessageListView: View {
    @Query private var messages: [Message]
    @Binding var selection: String?

    @StateObject private var auth = AuthManager.shared
    @StateObject private var mailSync = MailSyncEngine.shared
    @Environment(\.modelContext) private var modelContext

    init(mailboxName: String, selection: Binding<String?>) {
        _messages = Query(
            filter: #Predicate<Message> { $0.mailboxName == mailboxName },
            sort: [SortDescriptor(\Message.receivedAt, order: .reverse)]
        )
        _selection = selection
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(messages, id: \.messageId) { message in
                MessageRow(message: message)
                    .tag(message.messageId)
            }

            if mailSync.nextPageToken != nil {
                HStack {
                    Spacer()
                    if mailSync.isSyncing {
                        ProgressView()
                    } else {
                        Button("Load More") {
                            Task { await loadMore() }
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
        .overlay {
            if messages.isEmpty {
                ContentUnavailableView("No Messages", systemImage: "tray")
            }
        }
    }

    private func loadMore() async {
        guard let token = try? await auth.validGmailAccessToken() else { return }
        await mailSync.loadMoreMessages(accessToken: token, modelContext: modelContext)
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
