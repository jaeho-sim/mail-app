//
//  SyncService.swift
//  MailApp
//
//  Reads/writes user config to Firestore, keyed by the signed-in Google user's UID.
//  This is what makes settings follow the user across Mac and iPhone.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()

    @Published var signature: String = ""
    @Published var preferredTheme: String = "system"
    @Published var syncIntervalMinutes: Double = 5
    @Published var favoriteMailboxes: [PinnedMailboxRef] = []
    @Published var isSyncing = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    private init() {}

    /// Awaits the fetch so callers can rely on the values being current before
    /// using them (e.g. scheduling the periodic sync timer at launch).
    func loadConfig(for userId: String) async {
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        do {
            let snapshot = try await db.collection("userConfigs").document(userId).getDocument()
            let data = snapshot.data()
            signature = data?["signature"] as? String ?? ""
            preferredTheme = data?["preferredTheme"] as? String ?? "system"
            syncIntervalMinutes = data?["syncIntervalMinutes"] as? Double ?? 5
            let favoritesData = data?["favoriteMailboxes"] as? [[String: String]] ?? []
            favoriteMailboxes = favoritesData.compactMap { dict in
                guard let email = dict["accountEmail"], let name = dict["mailboxName"] else { return nil }
                return PinnedMailboxRef(accountEmail: email, mailboxName: name)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveConfig(for userId: String) {
        isSyncing = true
        errorMessage = nil
        let data: [String: Any] = [
            "signature": signature,
            "preferredTheme": preferredTheme,
            "syncIntervalMinutes": syncIntervalMinutes,
            "favoriteMailboxes": favoriteMailboxes.map {
                ["accountEmail": $0.accountEmail, "mailboxName": $0.mailboxName]
            },
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        Task {
            defer { isSyncing = false }
            do {
                try await db.collection("userConfigs").document(userId).setData(data, merge: true)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Favorites

    func isFavorite(_ ref: PinnedMailboxRef) -> Bool {
        favoriteMailboxes.contains(ref)
    }

    func addFavorite(_ ref: PinnedMailboxRef, for userId: String) {
        guard !favoriteMailboxes.contains(ref) else { return }
        favoriteMailboxes.append(ref)
        saveConfig(for: userId)
    }

    func removeFavorite(_ ref: PinnedMailboxRef, for userId: String) {
        favoriteMailboxes.removeAll { $0 == ref }
        saveConfig(for: userId)
    }
}
