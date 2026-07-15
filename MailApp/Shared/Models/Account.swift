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

    init(email: String, displayName: String, provider: AccountProvider, createdAt: Date = .now) {
        self.email = email
        self.displayName = displayName
        self.provider = provider
        self.createdAt = createdAt
    }
}
