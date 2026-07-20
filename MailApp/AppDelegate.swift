//
//  AppDelegate.swift
//  MailApp
//
//  SwiftUI's App protocol doesn't expose APNs device-token callbacks or
//  silent-push handling directly, so this bridges in via
//  @UIApplicationDelegateAdaptor / @NSApplicationDelegateAdaptor (wired up
//  in MailAppApp.swift). Hands the APNs token to Firebase Messaging (which
//  maps it to an FCM token), and wakes a targeted sync when a silent push
//  arrives.
//

import Foundation
import FirebaseMessaging
import UserNotifications

#if os(iOS)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        Messaging.messaging().delegate = PushRegistrar.shared
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Not fatal — local notifications and manual/periodic sync keep working regardless.
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        await PushRegistrar.shared.handleRemoteNotification(userInfo)
        return .newData
    }
}
#elseif os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        Messaging.messaging().delegate = PushRegistrar.shared
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Not fatal — local notifications and manual/periodic sync keep working regardless.
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        Task { await PushRegistrar.shared.handleRemoteNotification(userInfo) }
    }
}
#endif
