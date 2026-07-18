//
//  MessageDetailView.swift
//  MailApp
//
//  The reading pane (right column). Lazily fetches the full HTML/plain-text
//  body the first time a message is opened (list sync only stores headers +
//  snippet), then renders it — HTML via a sandboxed WKWebView, plain text as
//  regular SwiftUI Text. Falls back to the snippet while the body loads or
//  if Gmail returns no body at all.
//

import SwiftUI
import SwiftData

struct MessageDetailView: View {
    @Query private var messages: [Message]
    @Environment(\.modelContext) private var modelContext
    @State private var isFetchingBody = false

    init(messageId: String) {
        _messages = Query(filter: #Predicate<Message> { $0.messageId == messageId })
    }

    private var message: Message? { messages.first }

    var body: some View {
        if let message {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(message.subject)
                        .font(.title2.bold())

                    HStack(alignment: .top) {
                        Circle()
                            .fill(.tint.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.tint)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.sender)
                                .font(.headline)
                            Text(message.receivedAt, format: .dateTime.month().day().year().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Divider()

                    bodyContent(for: message)
                }
                .padding(24)
            }
            .navigationTitle(message.subject)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task(id: message.messageId) {
                await loadBodyIfNeeded(message)
            }
        } else {
            ContentUnavailableView("Message Not Found", systemImage: "envelope")
        }
    }

    @ViewBuilder
    private func bodyContent(for message: Message) -> some View {
        if let html = message.htmlBody, !html.isEmpty {
            HTMLMessageView(html: html)
        } else if let plain = message.plainTextBody, !plain.isEmpty {
            Text(plain)
                .font(.body)
                .textSelection(.enabled)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(message.snippet)
                    .font(.body)
                    .textSelection(.enabled)
                if isFetchingBody {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func loadBodyIfNeeded(_ message: Message) async {
        guard message.htmlBody == nil, message.plainTextBody == nil else { return }
        isFetchingBody = true
        defer { isFetchingBody = false }
        guard let token = try? await AccountsManager.shared.accessToken(forAccountEmail: message.accountEmail) else {
            return
        }
        await MailSyncEngine.shared.fetchBody(for: message, accessToken: token, modelContext: modelContext)
    }
}
