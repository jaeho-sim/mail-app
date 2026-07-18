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
    let headers: [GmailHeader]?
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
