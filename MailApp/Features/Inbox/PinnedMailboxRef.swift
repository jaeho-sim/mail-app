//
//  PinnedMailboxRef.swift
//  MailApp
//
//  A lightweight reference to one account's mailbox, used for the sidebar's
//  Favorites section and persisted to Firestore so favorites follow you
//  across devices, like your signature and sync interval.
//

import Foundation

struct PinnedMailboxRef: Codable, Hashable {
    let accountEmail: String
    let mailboxName: String
}
