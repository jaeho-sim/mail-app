//
//  SettingsView.swift
//  MailApp
//
//  Account info, signature, and sync interval (all synced via Firestore), and sign out.
//

import SwiftUI
import FirebaseAuth

private let syncIntervalOptions: [Double] = [1, 5, 15, 30, 60]

struct SettingsView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var sync = SyncService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section("App Sign-In") {
                    if let user = auth.currentUser {
                        LabeledContent("Email", value: user.email ?? user.uid)
                    }
                    Button("Sign Out", role: .destructive) {
                        auth.signOut()
                        dismiss()
                    }
                }

                Section("Gmail Accounts") {
                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label("Manage Accounts", systemImage: "person.2.circle")
                    }
                }

                Section("Signature") {
                    TextEditor(text: $sync.signature)
                        .frame(minHeight: 100)
                }

                Section {
                    Picker("Sync Every", selection: $sync.syncIntervalMinutes) {
                        ForEach(syncIntervalOptions, id: \.self) { minutes in
                            Text(minutes == 1 ? "1 Minute" : "\(Int(minutes)) Minutes")
                                .tag(minutes)
                        }
                    }
                } header: {
                    Text("Sync Interval")
                } footer: {
                    Text("How often the app checks for new mail while it's open. This doesn't affect true background delivery, which needs push notifications (not set up yet).")
                }

                if sync.isSyncing {
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let user = auth.currentUser {
                            sync.saveConfig(for: user.uid)
                        }
                        PeriodicSyncManager.shared.start(
                            interval: sync.syncIntervalMinutes * 60,
                            modelContext: modelContext
                        )
                        dismiss()
                    }
                }
            }
            .task {
                if let user = auth.currentUser {
                    await sync.loadConfig(for: user.uid)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
