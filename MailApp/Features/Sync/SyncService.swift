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
    @Published var isSyncing = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    private init() {}

    func loadConfig(for userId: String) {
        isSyncing = true
        errorMessage = nil
        Task {
            defer { isSyncing = false }
            do {
                let snapshot = try await db.collection("userConfigs").document(userId).getDocument()
                let data = snapshot.data()
                signature = data?["signature"] as? String ?? ""
                preferredTheme = data?["preferredTheme"] as? String ?? "system"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func saveConfig(for userId: String) {
        isSyncing = true
        errorMessage = nil
        let data: [String: Any] = [
            "signature": signature,
            "preferredTheme": preferredTheme,
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
}
