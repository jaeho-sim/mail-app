//
//  MailAppApp.swift
//  MailApp
//
//  Created by Jaeho Sim on 2026-07-15.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct MailAppApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Account.self, Mailbox.self, Message.self, UserConfig.self])
    }
}
