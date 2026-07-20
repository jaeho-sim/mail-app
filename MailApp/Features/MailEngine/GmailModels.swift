//
//  GmailModels.swift
//  MailApp
//
//  Codable mirrors of the Gmail REST API JSON shapes we use.
//  https://developers.google.com/gmail/api/reference/rest/v1/users.messages
//

import Foundation

struct GmailListMessagesResponse: Decodable {
    let messages: [GmailMessageRef]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageRef: Decodable {
    let id: String
    let threadId: String
}

struct GmailMessage: Decodable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let payload: GmailPayload?
    let internalDate: String?
}

struct GmailPayload: Decodable {
    let mimeType: String?
    let filename: String?
    let headers: [GmailHeader]?
    let body: GmailPartBody?
    let parts: [GmailPayload]?
}

/// Gmail base64url-encodes the actual body content; `size` is informational.
/// `attachmentId` is present on attachment parts (their `data` is omitted
/// here and must be fetched separately via `messages/{id}/attachments/{attachmentId}`).
struct GmailPartBody: Decodable {
    let attachmentId: String?
    let size: Int?
    let data: String?
}

/// Response shape of `GET messages/{messageId}/attachments/{attachmentId}`.
struct GmailAttachmentPayload: Decodable {
    let size: Int?
    let data: String?
}

struct GmailHeader: Decodable {
    let name: String
    let value: String
}

struct GmailLabel: Decodable {
    let id: String
    let name: String
    let type: String?
}

struct GmailListLabelsResponse: Decodable {
    let labels: [GmailLabel]
}

/// Several Gmail write endpoints (modify, trash, send) return the affected
/// message resource. We don't need its contents, so this decodes trivially
/// against any valid JSON object.
struct EmptyResponse: Decodable {}

/// Response from `users.watch` — registers push notifications (via Pub/Sub)
/// for changes to this mailbox. `expiration` is epoch milliseconds, as a string.
struct GmailWatchResponse: Decodable {
    let historyId: String?
    let expiration: String?
}
