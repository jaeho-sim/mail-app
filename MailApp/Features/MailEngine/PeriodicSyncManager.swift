//
//  PeriodicSyncManager.swift
//  MailApp
//
//  Re-syncs all connected accounts on a timer while the app is open (foreground/running).
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
    private var modelContext: ModelContext?

    private init() {}

    func start(interval: TimeInterval = 5 * 60, modelContext: ModelContext) {
        self.modelContext = modelContext
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncNow()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func syncNow() async {
        guard let modelContext else { return }
        let accounts = (try? modelContext.fetch(FetchDescriptor<Account>())) ?? []
        guard !accounts.isEmpty else { return }
        await MailSyncEngine.shared.syncAllAccounts(accounts, modelContext: modelContext)
    }
}
