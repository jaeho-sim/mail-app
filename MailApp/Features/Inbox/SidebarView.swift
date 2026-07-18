//
//  SidebarView.swift
//  MailApp
//
//  Mailbox list (Inbox, Sent, labels, etc.), styled after Mail.app's sidebar.
//

import SwiftUI

struct SidebarView: View {
    let mailboxes: [Mailbox]
    @Binding var selection: String?

    var body: some View {
        List(selection: $selection) {
            ForEach(mailboxes, id: \.name) { mailbox in
                Label {
                    HStack {
                        Text(mailbox.name.capitalized)
                        Spacer()
                        if mailbox.unreadCount > 0 {
                            Text("\(mailbox.unreadCount)")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(.tint, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                } icon: {
                    Image(systemName: icon(for: mailbox.name))
                        .foregroundStyle(.tint)
                }
                .tag(mailbox.name)
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
    }

    private func icon(for name: String) -> String {
        switch name.uppercased() {
        case "INBOX": return "tray.fill"
        case "SENT": return "paperplane.fill"
        case "DRAFT", "DRAFTS": return "doc.fill"
        case "TRASH": return "trash.fill"
        case "SPAM": return "exclamationmark.octagon.fill"
        case "STARRED": return "star.fill"
        case "IMPORTANT": return "flag.fill"
        default: return "folder.fill"
        }
    }
}
