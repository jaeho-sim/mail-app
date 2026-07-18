//
//  SidebarView.swift
//  MailApp
//
//  Mailbox list: unified inbox, flagged, favorites, then each account's own
//  mailboxes grouped below — styled after Mail.app's sidebar. Favorite a
//  mailbox via its context menu (long-press on iOS, right-click on Mac).
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct SidebarView: View {
    let accounts: [Account]
    let mailboxes: [Mailbox]
    @Binding var selection: MailboxSelection?

    @StateObject private var auth = AuthManager.shared
    @StateObject private var syncService = SyncService.shared

    @Query(filter: #Predicate<Message> { $0.isFlagged == true }) private var flaggedMessages: [Message]

    /// Accounts whose mailbox list is collapsed. Absent from this set = expanded
    /// (so newly-added accounts default to expanded, not collapsed).
    @State private var collapsedAccounts: Set<String> = []

    var body: some View {
        List(selection: $selection) {
            Section {
                mailboxLabel(title: "All Inboxes", icon: "tray.2.fill", tint: .accentColor, count: unifiedUnreadCount)
                    .tag(MailboxSelection.unified)

                mailboxLabel(title: "Flagged", icon: "flag.fill", tint: .orange, count: flaggedMessages.count)
                    .tag(MailboxSelection.flagged)
            }

            if !syncService.favoriteMailboxes.isEmpty {
                Section("Favorites") {
                    ForEach(syncService.favoriteMailboxes, id: \.self) { ref in
                        mailboxLabel(
                            title: "\(ref.mailboxName.capitalized) — \(ref.accountEmail)",
                            icon: icon(for: ref.mailboxName),
                            tint: .accentColor,
                            count: unreadCount(accountEmail: ref.accountEmail, mailboxName: ref.mailboxName)
                        )
                        .tag(MailboxSelection.account(email: ref.accountEmail, mailboxName: ref.mailboxName))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeFavorite(ref)
                            } label: {
                                Label("Remove", systemImage: "star.slash")
                            }
                        }
                    }
                }
            }

            ForEach(accounts, id: \.email) { account in
                DisclosureGroup(isExpanded: expandedBinding(for: account.email)) {
                    ForEach(mailboxesFor(account), id: \.name) { mailbox in
                        let ref = PinnedMailboxRef(accountEmail: account.email, mailboxName: mailbox.name)
                        mailboxLabel(
                            title: mailbox.name.capitalized,
                            icon: icon(for: mailbox.name),
                            tint: .accentColor,
                            count: mailbox.unreadCount
                        )
                        .tag(MailboxSelection.account(email: account.email, mailboxName: mailbox.name))
                        .contextMenu {
                            if syncService.isFavorite(ref) {
                                Button {
                                    removeFavorite(ref)
                                } label: {
                                    Label("Remove from Favorites", systemImage: "star.slash")
                                }
                            } else {
                                Button {
                                    addFavorite(ref)
                                } label: {
                                    Label("Add to Favorites", systemImage: "star")
                                }
                            }
                        }
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

    private func addFavorite(_ ref: PinnedMailboxRef) {
        guard let user = auth.currentUser else { return }
        syncService.addFavorite(ref, for: user.uid)
    }

    private func removeFavorite(_ ref: PinnedMailboxRef) {
        guard let user = auth.currentUser else { return }
        syncService.removeFavorite(ref, for: user.uid)
    }

    private func mailboxesFor(_ account: Account) -> [Mailbox] {
        mailboxes.filter { $0.accountEmail == account.email }
    }

    private func unreadCount(accountEmail: String, mailboxName: String) -> Int {
        mailboxes.first { $0.accountEmail == accountEmail && $0.name == mailboxName }?.unreadCount ?? 0
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

    @ViewBuilder
    private func mailboxLabel(title: String, icon: String, tint: Color, count: Int) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                if count > 0 {
                    unreadBadge(count)
                }
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(tint)
        }
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
