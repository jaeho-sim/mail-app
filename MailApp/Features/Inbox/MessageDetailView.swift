//
//  MessageDetailView.swift
//  MailApp
//
//  The reading pane (right column). Shows the Gmail snippet for now — fetching
//  and rendering the full MIME body is a follow-up (Gmail's `format=full` plus
//  base64url + multipart parsing), not required for this pass.
//

import SwiftUI
import SwiftData

struct MessageDetailView: View {
    @Query private var messages: [Message]

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

                    Text(message.snippet)
                        .font(.body)
                        .textSelection(.enabled)
                }
                .padding(24)
            }
            .navigationTitle(message.subject)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } else {
            ContentUnavailableView("Message Not Found", systemImage: "envelope")
        }
    }
}
