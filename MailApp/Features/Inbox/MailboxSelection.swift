//
//  MailboxSelection.swift
//  MailApp
//
//  What's currently selected in the sidebar: either the unified inbox
//  (across all connected accounts) or one mailbox within one account.
//

import Foundation

enum MailboxSelection: Hashable {
    case unified
    case flagged
    case account(email: String, mailboxName: String)
}
