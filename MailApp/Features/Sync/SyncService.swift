//
//  SyncService.swift
//  MailApp
//
//  Reads/writes user config to Firestore, keyed by the signed-in Google user's UID.
//  This is what makes settings follow the user across Mac and iPhone.
//

import Foundation
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
        db.collection("userConfigs").document(userId).getDocument { [weak self] snapshot, error in
            guard let self else { return }
            self.isSyncing = false
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            let data = snapshot?.data()
            self.signature = data?["signature"] as? String ?? ""
            self.preferredTheme = data?["preferredTheme"] as? String ?? "system"
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
        db.collection("userConfigs").document(userId).setData(data, merge: true) { [weak self] error in
            self?.isSyncing = false
            if let error {
                self?.errorMessage = error.localizedDescription
            }
        }
    }
}
