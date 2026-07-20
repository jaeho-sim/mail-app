//
//  NotificationManager.swift
//  MailApp
//
//  Posts local notifications for new mail and sync errors, and — once an
//  account's Gmail watch + FCM token are registered (see PushRegistrar) —
//  also acts as the delegate that shows those notifications as banners even
//  while the app is in the foreground.
//

import Foundation
import UserNotifications

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    private override init() { super.init() }

    /// Call after connecting an account, or at launch if accounts already
    /// exist. Only prompts the very first time (`.notDetermined`) — if the
    /// user already said no, we don't nag them again. Also registers for
    /// remote (push) notifications once permission is granted, so silent
    /// pushes from the server relay can wake the app — see PushRegistrar.
    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async { Self.registerForRemoteNotifications() }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async { Self.registerForRemoteNotifications() }
            default:
                break
            }
        }
    }

    /// Posts a notification per new message, unless a lot arrived in one
    /// sync (e.g. after being offline a while) — then it summarizes instead
    /// of flooding the notification center with individual banners.
    func notifyNewMessages(_ messages: [Message]) {
        guard !messages.isEmpty else { return }
        let center = UNUserNotificationCenter.current()

        if messages.count > 3 {
            let content = UNMutableNotificationContent()
            content.title = "\(messages.count) New Messages"
            content.body = messages.prefix(3).map(\.sender).joined(separator: ", ") + ", and more"
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
            return
        }

        for message in messages {
            let content = UNMutableNotificationContent()
            content.title = message.sender
            content.subtitle = message.subject
            content.body = message.snippet
            content.sound = .default
            content.threadIdentifier = message.accountEmail
            center.add(UNNotificationRequest(identifier: message.messageId, content: content, trigger: nil))
        }
    }

    func notifySyncError(_ description: String) {
        let content = UNMutableNotificationContent()
        content.title = "Sync Error"
        content.body = description
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    private static func registerForRemoteNotifications() {
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS)
        NSApplication.shared.registerForRemoteNotifications()
        #endif
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Without this, notifications triggered while the app is frontmost
    /// wouldn't show anything — the default behavior is to suppress them.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
