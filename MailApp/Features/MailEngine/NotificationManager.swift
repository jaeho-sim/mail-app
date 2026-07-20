//
//  NotificationManager.swift
//  MailApp
//
//  Local notifications for new mail and sync errors. This works whenever the
//  app is running (foreground or briefly backgrounded) — it is NOT push, so
//  it won't fire while the app is fully closed/suspended. True background
//  delivery needs APNs + a server relay; see docs/PHASE5-BACKGROUND-PUSH.md.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    /// Call after connecting an account, or at launch if accounts already
    /// exist. Only prompts the very first time (`.notDetermined`) — if the
    /// user already said no, we don't nag them again.
    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
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
}
