//
//  MessageAttachmentInfo.swift
//  MailApp
//
//  Lightweight attachment metadata cached on a Message (filename/type/size
//  only — the actual bytes are fetched on demand when the user downloads it).
//

import Foundation

struct MessageAttachmentInfo: Codable, Hashable {
    let attachmentId: String
    let filename: String
    let mimeType: String
    let size: Int
}
