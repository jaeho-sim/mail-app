//
//  ContentView.swift
//  MailApp
//
//  Temporary test screen: verifies Google Sign-In, Firestore sync, and now
//  Gmail fetch (Phase 3). Will be replaced by the real 3-pane inbox UI in Phase 4.
//

import SwiftUI
import FirebaseAuth
import SwiftData

struct ContentView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var sync = SyncService.shared
    @StateObject private var mailSync = MailSyncEngine.shared

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Message.receivedAt, order: .reverse) private var messages: [Message]

    var body: some View {
        VStack(spacing: 16) {
            if let user = auth.currentUser {
                Text("Signed in as \(user.email ?? user.uid)")
                    .font(.headline)

                TextField("Signature", text: $sync.signature)
                    .padding(.horizontal)

                Button("Save to Firestore") {
                    sync.saveConfig(for: user.uid)
                }

                Button("Sync Inbox") {
                    Task {
                        let token = try? await auth.validGmailAccessToken()
                        guard let token else {
                            mailSync.errorMessage = "Could not get a Gmail access token."
                            return
                        }
                        await mailSync.syncInbox(
                            accountEmail: user.email ?? user.uid,
                            accessToken: token,
                            modelContext: modelContext
                        )
                    }
                }

                if sync.isSyncing || mailSync.isSyncing {
                    ProgressView()
                }

                Text("\(messages.count) messages cached locally")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(messages.prefix(10), id: \.messageId) { message in
                    VStack(alignment: .leading) {
                        Text(message.subject).font(.subheadline).bold()
                        Text(message.sender).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(maxHeight: 300)

                Button("Sign Out", role: .destructive) {
                    auth.signOut()
                }
            } else {
                Text("Mail App")
                    .font(.largeTitle)

                Button {
                    auth.signIn()
                } label: {
                    Label("Sign in with Google", systemImage: "person.crop.circle")
                }

                if auth.isSigningIn {
                    ProgressView()
                }
            }

            if let error = auth.errorMessage ?? sync.errorMessage ?? mailSync.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .padding()
        .onChange(of: auth.currentUser?.uid) { _, newUID in
            if let newUID {
                sync.loadConfig(for: newUID)
            }
        }
    }
}

#Preview {
    ContentView()
}
