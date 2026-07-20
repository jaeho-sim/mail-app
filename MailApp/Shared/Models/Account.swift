//
//  Account.swift
//  MailApp
//
//  A connected email account (Gmail today, Microsoft later).
//

import Foundation
import SwiftData

enum AccountProvider: String, Codable {
    case gmail
    case microsoft
}

@Model
final class Account {
    var email: String
    var displayName: String
    var provider: AccountProvider
    var createdAt: Date
    // Tracks whether this account's first sync (which downloads the existing
    // backlog) has happened yet — used to suppress "new mail" notifications
    // for mail that isn't actually new, just newly synced.
    var hasCompletedInitialSync: Bool = false
    // When Gmail's push "watch" on this mailbox expires (watches last ~7
    // days and must be renewed). Nil means we've never successfully watched
    // it — remote push notifications won't arrive until we do.
    var watchExpiration: Date?

    init(
        email: String,
        displayName: String,
        provider: AccountProvider,
        createdAt: Date = .now,
        hasCompletedInitialSync: Bool = false,
        watchExpiration: Date? = nil
    ) {
        self.email = email
        self.displayName = displayName
        self.provider = provider
        self.createdAt = createdAt
        self.hasCompletedInitialSync = hasCompletedInitialSync
        self.watchExpiration = watchExpiration
    }
}
