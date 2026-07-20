//
//  AccountsView.swift
//  MailApp
//
//  Add/remove connected Gmail accounts. Reachable from Settings.
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @StateObject private var accountsManager = AccountsManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.email) private var accounts: [Account]

    var body: some View {
        List {
            Section("Connected Accounts") {
                if accounts.isEmpty {
                    Text("No accounts connected yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(accounts, id: \.email) { account in
                    HStack {
                        Image(systemName: "envelope.circle.fill")
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(account.displayName)
                            Text(account.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: removeAccounts)
            }

            Section {
                Button {
                    Task { await accountsManager.addGoogleAccount(modelContext: modelContext) }
                } label: {
                    Label("Add Gmail Account", systemImage: "plus.circle")
                }
                if accountsManager.isAddingAccount {
                    ProgressView()
                }
            }

            if let error = accountsManager.errorMessage {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Accounts")
    }

    private func removeAccounts(at offsets: IndexSet) {
        let toRemove = offsets.map { accounts[$0] }
        Task {
            for account in toRemove {
                await accountsManager.removeAccount(account, modelContext: modelContext)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountsView()
    }
}
