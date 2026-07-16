//
//  AuthManager.swift
//  MailApp
//
//  Handles Google Sign-In and Firebase Auth on both iOS and macOS.
//

import Foundation
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

    private init() {
        currentUser = Auth.auth().currentUser
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
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
        GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { [weak self] result, error in
            guard let self else { return }
            self.isSigningIn = false

            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let googleUser = result?.user,
                  let idToken = googleUser.idToken?.tokenString else {
                self.errorMessage = "Google Sign-In did not return a valid token."
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: googleUser.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                if let error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                self?.currentUser = authResult?.user
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
}
