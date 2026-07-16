//
//  ContentView.swift
//  MailApp
//
//  Temporary Phase 2 test screen: verifies Google Sign-In + Firestore sync.
//  Will be replaced by the real 3-pane inbox UI in Phase 4.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var sync = SyncService.shared

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

                if sync.isSyncing {
                    ProgressView()
                }

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

            if let error = auth.errorMessage ?? sync.errorMessage {
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
