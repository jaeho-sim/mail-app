//
//  ComposeView.swift
//  MailApp
//
//  Minimal compose sheet, with a "From" account picker now that multiple
//  Gmail accounts can be connected. Note: sending requires the gmail.send
//  scope, which AccountsManager currently only requests gmail.readonly for.
//  Add gmail.send there + the Google Auth Platform Data Access tab, then
//  reconnect the account, before this will actually work.
//

import SwiftUI
import SwiftData

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.email) private var accounts: [Account]

    @State private var fromAccountEmail: String?
    @State private var to = ""
    @State private var subject = ""
    @State private var messageBody = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if accounts.count > 1 {
                    Picker("From", selection: $fromAccountEmail) {
                        ForEach(accounts, id: \.email) { account in
                            Text(account.email).tag(Optional(account.email))
                        }
                    }
                }
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
                    .disabled(to.isEmpty || isSending || fromAccountEmail == nil)
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
            .onAppear {
                if fromAccountEmail == nil {
                    fromAccountEmail = accounts.first?.email
                }
            }
        }
    }

    private func send() async {
        guard let fromAccountEmail else {
            errorMessage = "Add a Gmail account before composing."
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            let token = try await AccountsManager.shared.accessToken(forAccountEmail: fromAccountEmail)
            let raw = Self.makeRawMessage(to: to, subject: subject, body: messageBody)
            try await GmailAPIClient().sendRawMessage(rawRFC2822Base64URL: raw, accessToken: token)
            dismiss()
        } catch {
            errorMessage = "Sending failed: \(error.localizedDescription). If this is a scope error, add gmail.send in AccountsManager and the Google Auth Platform Data Access tab, then remove and re-add the account."
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
