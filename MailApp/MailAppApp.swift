//
//  MailAppApp.swift
//  MailApp
//
//  Created by Jaeho Sim on 2026-07-15.
//

import SwiftUI
import SwiftData
import FirebaseCore

/// A single shared container, rather than the `.modelContainer(for:)` scene
/// modifier's own private one — AppDelegate/PushRegistrar need to reach
/// SwiftData from outside the SwiftUI view hierarchy (e.g. handling a silent
/// push), so they construct a `ModelContext` from this same container.
extension ModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: Account.self, Mailbox.self, Message.self, UserConfig.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}

@main
struct MailAppApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(ModelContainer.shared)
    }
}
