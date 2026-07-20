//
//  AccountsManager.swift
//  MailApp
//
//  Manages connected Gmail accounts (plural), independent of the app's own
//  sign-in identity (AuthManager). Each account's refresh token lives in the
//  Keychain; access tokens are minted on demand via GoogleOAuthTokenRefresher.
//

import Foundation
import Combine
import SwiftData
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn

enum AccountsManagerError: LocalizedError {
    case missingClientID
    case missingRefreshToken
    case noPresentationAnchor
    case missingProfile

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Firebase is not configured (missing client ID)."
        case .missingRefreshToken:
            return "No stored credentials for this account — try removing and re-adding it."
        case .noPresentationAnchor:
            return "Couldn't find a window to present sign-in from."
        case .missingProfile:
            return "Google didn't return an account email."
        }
    }
}

@MainActor
final class AccountsManager: ObservableObject {
    static let shared = AccountsManager()

    @Published var isAddingAccount = false
    @Published var errorMessage: String?

    private let refresher = GoogleOAuthTokenRefresher()

    private init() {}

    /// Presents Google Sign-In to connect another Gmail account. Requests the
    /// gmail.modify scope (read + trash/archive/label-modify/send — everything
    /// except permanent delete, which this app doesn't use). This is
    /// intentionally separate from AuthManager's app-identity sign-in.
    func addGoogleAccount(modelContext: ModelContext) async {
        errorMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = AccountsManagerError.missingClientID.localizedDescription
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        #if os(iOS)
        guard let presenting = PlatformPresentation.presentingViewController() else {
            errorMessage = AccountsManagerError.noPresentationAnchor.localizedDescription
            return
        }
        #elseif os(macOS)
        guard let presenting = PlatformPresentation.presentingWindow() else {
            errorMessage = AccountsManagerError.noPresentationAnchor.localizedDescription
            return
        }
        #endif

        isAddingAccount = true
        defer { isAddingAccount = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenting,
                hint: nil,
                additionalScopes: ["https://www.googleapis.com/auth/gmail.modify"]
            )
            guard let email = result.user.profile?.email else {
                errorMessage = AccountsManagerError.missingProfile.localizedDescription
                return
            }
            let refreshToken = result.user.refreshToken.tokenString
            KeychainStore.save(refreshToken: refreshToken, forAccount: email)

            let descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.email == email })
            if (try? modelContext.fetch(descriptor).first) == nil {
                modelContext.insert(
                    Account(
                        email: email,
                        displayName: result.user.profile?.name ?? email,
                        provider: .gmail
                    )
                )
                try? modelContext.save()
            }

            // Sync immediately so this account's mailboxes show up in the sidebar
            // right away, rather than waiting for the next manual/periodic refresh.
            // Reuse the token we just got from sign-in instead of refreshing again.
            await MailSyncEngine.shared.syncAccount(
                accountEmail: email,
                accessToken: result.user.accessToken.tokenString,
                modelContext: modelContext
            )

            NotificationManager.shared.requestAuthorizationIfNeeded()

            let refreshedAccount = try? modelContext.fetch(descriptor).first
            if let refreshedAccount, let fcmToken = Messaging.messaging().fcmToken {
                await PushRegistrar.shared.register(account: refreshedAccount, fcmToken: fcmToken, modelContext: modelContext)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes a connected account: cancels its push subscription, then
    /// deletes its Keychain token and local Account/Mailbox/Message records.
    /// Does not touch the app's sign-in identity.
    func removeAccount(_ account: Account, modelContext: ModelContext) async {
        // Unregister push while the Keychain token still exists — it needs a
        // valid access token to tell Gmail to stop watching this mailbox.
        await PushRegistrar.shared.unregister(email: account.email, modelContext: modelContext)
        KeychainStore.deleteRefreshToken(forAccount: account.email)

        let email = account.email
        if let messages = try? modelContext.fetch(FetchDescriptor<Message>(predicate: #Predicate { $0.accountEmail == email })) {
            for message in messages { modelContext.delete(message) }
        }
        if let mailboxes = try? modelContext.fetch(FetchDescriptor<Mailbox>(predicate: #Predicate { $0.accountEmail == email })) {
            for mailbox in mailboxes { modelContext.delete(mailbox) }
        }
        modelContext.delete(account)
        try? modelContext.save()
    }

    /// Returns a valid (freshly refreshed) Gmail access token for the given account.
    func accessToken(forAccountEmail email: String) async throws -> String {
        guard let refreshToken = KeychainStore.refreshToken(forAccount: email) else {
            throw AccountsManagerError.missingRefreshToken
        }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AccountsManagerError.missingClientID
        }
        return try await refresher.refreshAccessToken(refreshToken: refreshToken, clientID: clientID)
    }
}
