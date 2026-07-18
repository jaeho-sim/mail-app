//
//  AuthManager.swift
//  MailApp
//
//  Handles the app's own sign-in identity (Google or Apple) — used only for
//  syncing settings across devices via SyncService. This is intentionally
//  separate from connected Gmail accounts; see AccountsManager for those.
//
//  Note: Sign in with Apple requires the "Sign in with Apple" capability,
//  which needs the paid Apple Developer Program to provision. Don't enable
//  that capability in Xcode until enrollment is active (same caution as
//  Push Notifications — see docs/PHASE5-BACKGROUND-PUSH.md).
//

import Foundation
import Combine
import CryptoKit
import Security
import AuthenticationServices
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isSigningIn = false
    @Published var errorMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var currentAppleNonce: String?

    private init() {
        currentUser = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

    // MARK: - Google

    func signInWithGoogle() {
        errorMessage = nil

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase is not configured (missing client ID)."
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        #if os(iOS)
        guard let presenting = PlatformPresentation.presentingViewController() else {
            errorMessage = "No view controller available to present sign-in."
            return
        }
        #elseif os(macOS)
        guard let presenting = PlatformPresentation.presentingWindow() else {
            errorMessage = "No window available to present sign-in."
            return
        }
        #endif

        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                // No Gmail scope here on purpose — this is app identity only.
                let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
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

    // MARK: - Apple

    /// Called from `SignInWithAppleButton`'s request-configuration closure.
    /// Returns the SHA256 hash to set on the request's `nonce`; the raw value
    /// is kept to pass to Firebase once Apple returns a credential.
    func startAppleSignInRequest() -> String {
        let raw = Self.randomNonceString()
        currentAppleNonce = raw
        return Self.sha256(raw)
    }

    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  let rawNonce = currentAppleNonce else {
                errorMessage = "Apple did not return a valid credential."
                return
            }

            let firebaseCredential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: identityToken,
                rawNonce: rawNonce
            )

            isSigningIn = true
            defer { isSigningIn = false }
            do {
                let authResult = try await Auth.auth().signIn(with: firebaseCredential)
                currentUser = authResult.user
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Shared

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Nonce helpers (Apple's recommended replay-attack mitigation)

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
