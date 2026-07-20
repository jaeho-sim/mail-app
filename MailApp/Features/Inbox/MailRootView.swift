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
    @StateObject private var accountsManager = AccountsManager.shared
    @StateObject private var mailSync = MailSyncEngine.shared
    @StateObject private var syncService = SyncService.shared
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.email) private var accounts: [Account]
    @Query(sort: \Mailbox.name) private var mailboxes: [Mailbox]

    @State private var selectedMailbox: MailboxSelection? = .unified
    @State private var selectedMessageID: String?
    @State private var showingCompose = false
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(accounts: accounts, mailboxes: mailboxes, selection: $selectedMailbox)
                .navigationTitle("Mailboxes")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingCompose = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .disabled(accounts.isEmpty)
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
            if accounts.isEmpty {
                addAccountPrompt
            } else {
                MessageListView(mailboxSelection: selectedMailbox ?? .unified, selection: $selectedMessageID)
                    .navigationTitle(title(for: selectedMailbox ?? .unified))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                Task { await syncAll() }
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
            }
        } detail: {
            if let selectedMessageID {
                MessageDetailView(messageId: selectedMessageID)
            } else {
                ContentUnavailableView("No Message Selected", systemImage: "envelope")
            }
        }
        .task {
            if !accounts.isEmpty {
                await syncAll()
                NotificationManager.shared.requestAuthorizationIfNeeded()
            }
            if let user = auth.currentUser {
                await syncService.loadConfig(for: user.uid)
            }
            PeriodicSyncManager.shared.start(
                interval: syncService.syncIntervalMinutes * 60,
                modelContext: modelContext
            )
        }
        .onDisappear {
            PeriodicSyncManager.shared.stop()
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

    private var addAccountPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.person.crop")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("No Gmail Accounts Connected")
                .font(.headline)
            Text("Add a Gmail account to start seeing mail here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Gmail Account") {
                Task { await accountsManager.addGoogleAccount(modelContext: modelContext) }
            }
            .buttonStyle(.borderedProminent)
            if accountsManager.isAddingAccount {
                ProgressView()
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func title(for selection: MailboxSelection) -> String {
        switch selection {
        case .unified:
            return "All Inboxes"
        case .flagged:
            return "Flagged"
        case .account(_, let mailboxName):
            return mailboxName.capitalized
        }
    }

    private func syncAll() async {
        await mailSync.syncAllAccounts(accounts, modelContext: modelContext)
    }
}

#Preview {
    MailRootView()
}
