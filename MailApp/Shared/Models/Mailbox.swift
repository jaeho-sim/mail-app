//
//  Mailbox.swift
//  MailApp
//
//  A folder/label within an account (Inbox, Sent, custom labels, etc.).
//

import Foundation
import SwiftData

@Model
final class Mailbox {
    var name: String
    var unreadCount: Int
    var accountEmail: String

    init(name: String, unreadCount: Int = 0, accountEmail: String) {
        self.name = name
        self.unreadCount = unreadCount
        self.accountEmail = accountEmail
    }
}
