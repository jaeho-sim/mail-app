//
//  AuthManager.swift
//  MailApp
//
//  Handles Google Sign-In and Firebase Auth on both iOS and macOS.
//

import Foundation
import Combine
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isSigningIn = false
    @Published var errorMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        currentUser = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

    func signIn() {
        errorMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase is not configured (missing client ID)."
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        #if os(iOS)
        guard let presenting = Self.presentingViewController() else {
            errorMessage = "No view controller available to present sign-in."
            return
        }
        #elseif os(macOS)
        guard let presenting = Self.presentingWindow() else {
            errorMessage = "No window available to present sign-in."
            return
        }
        #endif

        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                let signInResult = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presenting,
                    hint: nil,
                    additionalScopes: Self.gmailScopes
                )
                guard let idToken = signInResult.user.idToken?.tokenString else {
                    errorMessage = "Google Sign-In did not return a valid token."
                    return
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: signInResult.user.accessToken.tokenString
                )
                let authResult = try await Auth.auth().signIn(with: credential)
                currentUser = authResult.user
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if os(iOS)
    private static func presentingViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow }?.rootViewController
    }
    #elseif os(macOS)
    private static func presentingWindow() -> NSWindow? {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first
    }
    #endif

    // MARK: - Gmail access

    /// Matches the scopes enabled on the Google Auth Platform "Data Access" tab.
    /// Add gmail.send / gmail.modify here (and in the console) once Phase 3's
    /// send/archive/label actions are wired up.
    private static let gmailScopes = ["https://www.googleapis.com/auth/gmail.readonly"]

    /// Returns a valid (auto-refreshed) Gmail access token for the signed-in user.
    func validGmailAccessToken() async throws -> String {
        guard let googleUser = GIDSignIn.sharedInstance.currentUser else {
            throw AuthManagerError.notSignedIn
        }
        let refreshedUser = try await googleUser.refreshTokensIfNeeded()
        return refreshedUser.accessToken.tokenString
    }
}

enum AuthManagerError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You're not signed in with Google."
        }
    }
}
