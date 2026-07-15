//
//  UserConfig.swift
//  MailApp
//
//  User preferences synced across devices via the backend (Phase 2).
//

import Foundation
import SwiftData

@Model
final class UserConfig {
    var googleUserId: String
    var signature: String
    var preferredTheme: String
    var updatedAt: Date

    init(
        googleUserId: String,
        signature: String = "",
        preferredTheme: String = "system",
        updatedAt: Date = .now
    ) {
        self.googleUserId = googleUserId
        self.signature = signature
        self.preferredTheme = preferredTheme
        self.updatedAt = updatedAt
    }
}
