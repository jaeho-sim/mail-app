//
//  GoogleOAuthTokenRefresher.swift
//  MailApp
//
//  Exchanges a stored refresh token for a fresh access token directly against
//  Google's token endpoint. Needed for multi-account support since GIDSignIn's
//  refreshTokensIfNeeded() only works for the single "current" session — for
//  every other connected account we manage refresh ourselves.
//
//  Native/installed-app OAuth clients (like our iOS client) are "public"
//  clients per OAuth2 — no client secret is required for this exchange.
//

import Foundation

enum GoogleOAuthError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an unexpected response from Google's token endpoint."
        case .httpError(let code, let message):
            return "Google token refresh error \(code): \(message)"
        }
    }
}

struct GoogleOAuthTokenRefresher {
    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
    }

    func refreshAccessToken(refreshToken: String, clientID: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleOAuthError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw GoogleOAuthError.httpError(http.statusCode, message)
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data).access_token
    }
}
