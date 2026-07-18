//
//  ContentView.swift
//  MailApp
//
//  Top-level router: SignInView when signed out, the real 3-pane MailRootView
//  when signed in. The Phase 2/3 debug controls now live in SettingsView
//  (signature) and MailRootView's toolbar (sync).
//

import SwiftUI

struct ContentView: View {
    @StateObject private var auth = AuthManager.shared

    var body: some View {
        Group {
            if auth.currentUser != nil {
                MailRootView()
            } else {
                SignInView()
            }
        }
    }
}

#Preview {
    ContentView()
}
