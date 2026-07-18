//
//  SignInView.swift
//  MailApp
//
//  Shown when no user is signed in.
//

import SwiftUI

struct SignInView: View {
    @StateObject private var auth = AuthManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Mail")
                .font(.largeTitle.bold())

            Text("Sign in with Google to connect your Gmail account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                auth.signIn()
            } label: {
                Label("Sign in with Google", systemImage: "person.crop.circle")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

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
