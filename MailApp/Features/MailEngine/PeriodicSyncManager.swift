//
//  PeriodicSyncManager.swift
//  MailApp
//
//  Re-syncs the inbox on a timer while the app is open (foreground/running).
//  This is NOT true background execution — the app must be alive for it to fire.
//  Real background refresh (app suspended/closed) needs iOS's BGTaskScheduler,
//  and live push needs APNs — both require the Apple Developer Program, which
//  isn't active yet. See docs/PHASE5-BACKGROUND-PUSH.md for that plan.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class PeriodicSyncManager {
    static let shared = PeriodicSyncManager()

    private var timer: Timer?

    private init() {}

    func start(interval: TimeInterval = 5 * 60, modelContext: ModelContext) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                await PeriodicSyncManager.shared.syncNow(modelContext: modelContext)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func syncNow(modelContext: ModelContext) async {
        guard let user = AuthManager.shared.currentUser else { return }
        guard let token = try? await AuthManager.shared.validGmailAccessToken() else { return }
        await MailSyncEngine.shared.syncInbox(
            accountEmail: user.email ?? user.uid,
            accessToken: token,
            modelContext: modelContext
        )
    }
}
