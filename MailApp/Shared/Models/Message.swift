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

    init(
        messageId: String,
        subject: String,
        sender: String,
        snippet: String,
        receivedAt: Date,
        isRead: Bool = false,
        mailboxName: String
    ) {
        self.messageId = messageId
        self.subject = subject
        self.sender = sender
        self.snippet = snippet
        self.receivedAt = receivedAt
        self.isRead = isRead
        self.mailboxName = mailboxName
    }
}
