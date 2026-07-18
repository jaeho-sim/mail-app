//
//  Message.swift
//  MailApp
//
//  A cached email message.
//

import Foundation
import SwiftData

@Model
final class Message {
    var messageId: String
    var subject: String
    var sender: String
    var snippet: String
    var receivedAt: Date
    var isRead: Bool
    var mailboxName: String
    var accountEmail: String = ""
    // Mirrors Gmail's STARRED label, which is also what Apple Mail's flag
    // (\Flagged over IMAP) maps to — so this stays in sync with native Mail.
    var isFlagged: Bool = false

    init(
        messageId: String,
        subject: String,
        sender: String,
        snippet: String,
        receivedAt: Date,
        isRead: Bool = false,
        mailboxName: String,
        accountEmail: String,
        isFlagged: Bool = false
    ) {
        self.messageId = messageId
        self.subject = subject
        self.sender = sender
        self.snippet = snippet
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.mailboxName = mailboxName
        self.accountEmail = accountEmail
        self.isFlagged = isFlagged
    }
}
