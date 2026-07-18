//
//  SettingsView.swift
//  MailApp
//
//  Account info, signature (synced via Firestore), and sign out.
//

import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var sync = SyncService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let user = auth.currentUser {
                        LabeledContent("Email", value: user.email ?? user.uid)
                    }
                    Button("Sign Out", role: .destructive) {
                        auth.signOut()
                        dismiss()
                    }
                }

                Section("Signature") {
                    TextEditor(text: $sync.signature)
                        .frame(minHeight: 100)
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
                        dismiss()
                    }
                }
            }
            .task {
                if let user = auth.currentUser {
                    sync.loadConfig(for: user.uid)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
