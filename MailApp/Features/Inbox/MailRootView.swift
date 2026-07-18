//
//  MailRootView.swift
//  MailApp
//
//  The real 3-pane layout: mailboxes | message list | reading pane.
//  NavigationSplitView collapses to stacked navigation automatically on iPhone.
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct MailRootView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var mailSync = MailSyncEngine.shared
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Mailbox.name) private var mailboxes: [Mailbox]

    @State private var selectedMailboxName: String? = "INBOX"
    @State private var selectedMessageID: String?
    @State private var showingCompose = false
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(mailboxes: mailboxes, selection: $selectedMailboxName)
                .navigationTitle("Mailboxes")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCompose = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        } content: {
            MessageListView(mailboxName: selectedMailboxName ?? "INBOX", selection: $selectedMessageID)
                .navigationTitle((selectedMailboxName ?? "Inbox").capitalized)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await sync() }
                        } label: {
                            if mailSync.isSyncing {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(mailSync.isSyncing)
                    }
                }
        } detail: {
            if let selectedMessageID {
                MessageDetailView(messageId: selectedMessageID)
            } else {
                ContentUnavailableView("No Message Selected", systemImage: "envelope")
            }
        }
        .task {
            if mailboxes.isEmpty {
                await sync()
            }
        }
        .sheet(isPresented: $showingCompose) {
            ComposeView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert(
            "Sync Error",
            isPresented: Binding(
                get: { mailSync.errorMessage != nil },
                set: { isPresented in if !isPresented { mailSync.errorMessage = nil } }
            )
        ) {
            Button("OK") { mailSync.errorMessage = nil }
        } message: {
            Text(mailSync.errorMessage ?? "")
        }
    }

    private func sync() async {
        guard let user = auth.currentUser else { return }
        guard let token = try? await auth.validGmailAccessToken() else {
            mailSync.errorMessage = "Could not get a Gmail access token."
            return
        }
        await mailSync.syncInbox(accountEmail: user.email ?? user.uid, accessToken: token, modelContext: modelContext)
    }
}

#Preview {
    MailRootView()
}
