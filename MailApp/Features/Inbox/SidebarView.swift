//
//  SidebarView.swift
//  MailApp
//
//  Mailbox list: a unified inbox across all connected accounts, then each
//  account's own mailboxes grouped below it — styled after Mail.app's sidebar.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    let accounts: [Account]
    let mailboxes: [Mailbox]
    @Binding var selection: MailboxSelection?

    @Query(filter: #Predicate<Message> { $0.isFlagged == true }) private var flaggedMessages: [Message]

    /// Accounts whose mailbox list is collapsed. Absent from this set = expanded
    /// (so newly-added accounts default to expanded, not collapsed).
    @State private var collapsedAccounts: Set<String> = []

    var body: some View {
        List(selection: $selection) {
            Section {
                Label {
                    HStack {
                        Text("All Inboxes")
                        Spacer()
                        if unifiedUnreadCount > 0 {
                            unreadBadge(unifiedUnreadCount)
                        }
                    }
                } icon: {
                    Image(systemName: "tray.2.fill")
                        .foregroundStyle(.tint)
                }
                .tag(MailboxSelection.unified)

                Label {
                    HStack {
                        Text("Flagged")
                        Spacer()
                        if !flaggedMessages.isEmpty {
                            unreadBadge(flaggedMessages.count)
                        }
                    }
                } icon: {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(.orange)
                }
                .tag(MailboxSelection.flagged)
            }

            ForEach(accounts, id: \.email) { account in
                DisclosureGroup(isExpanded: expandedBinding(for: account.email)) {
                    ForEach(mailboxesFor(account), id: \.name) { mailbox in
                        Label {
                            HStack {
                                Text(mailbox.name.capitalized)
                                Spacer()
                                if mailbox.unreadCount > 0 {
                                    unreadBadge(mailbox.unreadCount)
                                }
                            }
                        } icon: {
                            Image(systemName: icon(for: mailbox.name))
                                .foregroundStyle(.tint)
                        }
                        .tag(MailboxSelection.account(email: account.email, mailboxName: mailbox.name))
                    }
                } label: {
                    Text(account.email)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        #if os(macOS)
        .listStyle(.sidebar)
        #endif
    }

    private func mailboxesFor(_ account: Account) -> [Mailbox] {
        mailboxes.filter { $0.accountEmail == account.email }
    }

    private func expandedBinding(for email: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedAccounts.contains(email) },
            set: { isExpanded in
                if isExpanded {
                    collapsedAccounts.remove(email)
                } else {
                    collapsedAccounts.insert(email)
                }
            }
        )
    }

    private var unifiedUnreadCount: Int {
        mailboxes.filter { $0.name.uppercased() == "INBOX" }.reduce(0) { $0 + $1.unreadCount }
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(.tint, in: Capsule())
            .foregroundStyle(.white)
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
