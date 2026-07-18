//
//  SignInView.swift
//  MailApp
//
//  Shown when no app identity is signed in. This is separate from connecting
//  Gmail accounts — see AccountsView, reachable from Settings once signed in.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var auth = AuthManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Mail")
                .font(.largeTitle.bold())

            Text("Sign in to sync your settings across devices. You'll connect Gmail accounts separately, in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            VStack(spacing: 12) {
                Button {
                    auth.signInWithGoogle()
                } label: {
                    Label("Sign in with Google", systemImage: "person.crop.circle")
                        .frame(maxWidth: 280)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = auth.startAppleSignInRequest()
                } onCompletion: { result in
                    Task { await auth.handleAppleSignInCompletion(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(maxWidth: 280, maxHeight: 44)
            }

            if auth.isSigningIn {
                ProgressView()
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SignInView()
}
