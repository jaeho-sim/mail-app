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
    // Full MIME body, fetched lazily (on opening the message, not during
    // list sync) and cached here. htmlBody is preferred for rendering;
    // plainTextBody is the fallback for messages with no HTML part.
    var htmlBody: String?
    var plainTextBody: String?
    // Attachment metadata, populated alongside htmlBody/plainTextBody on the
    // same lazy full-body fetch. Actual bytes are downloaded on demand.
    var attachments: [MessageAttachmentInfo] = []
    // Whether the full-body fetch has run at all. This is the actual gate for
    // re-fetching — separate from htmlBody/plainTextBody being nil — so that
    // improvements to what we extract (e.g. attachments added after a message
    // was already opened once) get backfilled the next time it's opened,
    // instead of being skipped forever just because a body was already cached.
    var hasFetchedFullBody: Bool = false

    init(
        messageId: String,
        subject: String,
        sender: String,
        snippet: String,
        receivedAt: Date,
        isRead: Bool = false,
        mailboxName: String,
        accountEmail: String,
        isFlagged: Bool = false,
        htmlBody: String? = nil,
        plainTextBody: String? = nil,
        attachments: [MessageAttachmentInfo] = [],
        hasFetchedFullBody: Bool = false
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
        self.htmlBody = htmlBody
        self.plainTextBody = plainTextBody
        self.attachments = attachments
        self.hasFetchedFullBody = hasFetchedFullBody
    }
}
