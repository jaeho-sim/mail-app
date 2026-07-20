//
//  PushRegistrar.swift
//  MailApp
//
//  Wires this device up to receive a remote (silent) push whenever a
//  connected Gmail account gets new mail, even while the app isn't running.
//  Two things have to stay registered for that to work:
//    1. Firestore knows this device's FCM token for each connected Gmail
//       address (`pushSubscriptions`), so the server-side relay knows where
//       to send the push.
//    2. Gmail's own `users.watch` is active on the mailbox (expires every
//       ~7 days, renewed opportunistically here).
//  See docs/PHASE5-BACKGROUND-PUSH.md for the server side (Cloud Function
//  relay) this depends on.
//

import Foundation
import FirebaseFirestore
import FirebaseMessaging
import SwiftData

@MainActor
final class PushRegistrar: NSObject, ObservableObject {
    static let shared = PushRegistrar()

    private let db = Firestore.firestore()
    private let client = GmailAPIClient()

    // Must match the Pub/Sub topic Gmail's watch API publishes to — see
    // docs/PHASE5-BACKGROUND-PUSH.md for how to create it. Update
    // "mail-app-1" if your Firebase/GCP project ID differs.
    private let gmailWatchTopic = "projects/mail-app-1/topics/gmail-inbox-updates"

    private override init() { super.init() }

    /// Re-registers every connected account's push subscription. Safe to
    /// call often (e.g. every periodic sync tick) — it only actually hits
    /// the network for accounts whose watch is missing or about to expire.
    func registerAllAccounts(modelContext: ModelContext) async {
        guard let fcmToken = Messaging.messaging().fcmToken else { return }
        let accounts = (try? modelContext.fetch(FetchDescriptor<Account>())) ?? []
        for account in accounts {
            await register(account: account, fcmToken: fcmToken, modelContext: modelContext)
        }
    }

    func register(account: Account, fcmToken: String, modelContext: ModelContext) async {
        do {
            // ownerUid ties this subscription to the app's signed-in identity
            // (AuthManager, not per-Gmail-account) so Firestore rules can
            // scope access the same way userConfigs does.
            try await db.collection("pushSubscriptions")
                .document(subscriptionDocID(email: account.email, token: fcmToken))
                .setData([
                    "gmailAddress": account.email,
                    "fcmToken": fcmToken,
                    "platform": Self.platformName,
                    "ownerUid": AuthManager.shared.currentUser?.uid ?? "",
                    "updatedAt": FieldValue.serverTimestamp(),
                ])

            let needsWatch = account.watchExpiration == nil
                || account.watchExpiration! < Date.now.addingTimeInterval(24 * 60 * 60)
            guard needsWatch else { return }

            let accessToken = try await AccountsManager.shared.accessToken(forAccountEmail: account.email)
            let response = try await client.watchMailbox(topicName: gmailWatchTopic, accessToken: accessToken)
            if let expirationMillis = response.expiration, let millis = Double(expirationMillis) {
                account.watchExpiration = Date(timeIntervalSince1970: millis / 1000)
                try? modelContext.save()
            }
        } catch {
            // Best-effort — local notifications and manual/periodic sync still work without push.
        }
    }

    /// Called when disconnecting an account — cancels the Gmail-side watch
    /// and removes this device's subscription doc so the relay stops trying
    /// to notify it.
    func unregister(email: String, modelContext: ModelContext) async {
        if let fcmToken = Messaging.messaging().fcmToken {
            try? await db.collection("pushSubscriptions")
                .document(subscriptionDocID(email: email, token: fcmToken))
                .delete()
        }
        if let accessToken = try? await AccountsManager.shared.accessToken(forAccountEmail: email) {
            try? await client.stopWatchingMailbox(accessToken: accessToken)
        }
    }

    /// Called when a silent push wakes the app. The push payload only tells
    /// us *which* account changed, not what — we re-sync that one account,
    /// and MailSyncEngine's existing new-mail detection takes care of
    /// surfacing the actual local notification once it finds new messages.
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let gmailAddress = userInfo["gmailAddress"] as? String else { return }
        let modelContext = ModelContext(ModelContainer.shared)
        guard let accessToken = try? await AccountsManager.shared.accessToken(forAccountEmail: gmailAddress) else { return }
        await MailSyncEngine.shared.syncAccount(accountEmail: gmailAddress, accessToken: accessToken, modelContext: modelContext)
    }

    private func subscriptionDocID(email: String, token: String) -> String {
        // One doc per (account, device) pair, so multiple accounts and/or
        // multiple devices don't overwrite each other's subscriptions.
        "\(email)_\(token)".replacingOccurrences(of: "/", with: "_")
    }

    private static var platformName: String {
        #if os(iOS)
        "ios"
        #elseif os(macOS)
        "macos"
        #else
        "other"
        #endif
    }
}

extension PushRegistrar: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard fcmToken != nil else { return }
        Task { @MainActor in
            await PushRegistrar.shared.registerAllAccounts(modelContext: ModelContext(ModelContainer.shared))
        }
    }
}
