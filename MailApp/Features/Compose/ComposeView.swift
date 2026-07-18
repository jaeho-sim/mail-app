//
//  ComposeView.swift
//  MailApp
//
//  Minimal compose sheet. Note: sending requires the gmail.send scope, which
//  Phase 3 did not request (only gmail.readonly). Add it to AuthManager's
//  gmailScopes + the Google Auth Platform Data Access tab before this will work.
//

import SwiftUI

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var to = ""
    @State private var subject = ""
    @State private var messageBody = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("To", text: $to)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                TextField("Subject", text: $subject)
                TextEditor(text: $messageBody)
                    .frame(minHeight: 200)
            }
            .navigationTitle("New Message")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task { await send() }
                    }
                    .disabled(to.isEmpty || isSending)
                }
            }
            .overlay {
                if isSending {
                    ProgressView()
                }
            }
            .alert(
                "Couldn't Send",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { isPresented in if !isPresented { errorMessage = nil } }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        do {
            let token = try await AuthManager.shared.validGmailAccessToken()
            let raw = Self.makeRawMessage(to: to, subject: subject, body: messageBody)
            try await GmailAPIClient().sendRawMessage(rawRFC2822Base64URL: raw, accessToken: token)
            dismiss()
        } catch {
            errorMessage = "Sending failed: \(error.localizedDescription). If this is a scope error, add gmail.send in AuthManager and the Google Auth Platform Data Access tab, then sign in again."
        }
    }

    private static func makeRawMessage(to: String, subject: String, body: String) -> String {
        let message = "To: \(to)\r\nSubject: \(subject)\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n\(body)"
        guard let data = message.data(using: .utf8) else { return "" }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

#Preview {
    ComposeView()
}
