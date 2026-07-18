//
//  GmailAPIClient.swift
//  MailApp
//
//  Thin async/await wrapper around the Gmail REST API. Stateless — callers
//  pass a fresh access token per call (see AuthManager.validGmailAccessToken()).
//

import Foundation

enum GmailAPIError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Received an unexpected response from Gmail."
        case .httpError(let code, let message):
            return "Gmail API error \(code): \(message)"
        }
    }
}

struct GmailAPIClient {
    private let baseURL = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func listMessages(labelId: String = "INBOX", maxResults: Int = 25, pageToken: String? = nil, accessToken: String) async throws -> GmailListMessagesResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "labelIds", value: labelId),
            URLQueryItem(name: "maxResults", value: String(maxResults)),
        ]
        if let pageToken {
            queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = queryItems
        return try await get(components.url!, accessToken: accessToken)
    }

    func getMessage(id: String, accessToken: String) async throws -> GmailMessage {
        var components = URLComponents(url: baseURL.appendingPathComponent("messages/\(id)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "format", value: "metadata"),
            URLQueryItem(name: "metadataHeaders", value: "Subject"),
            URLQueryItem(name: "metadataHeaders", value: "From"),
        ]
        return try await get(components.url!, accessToken: accessToken)
    }

    func listLabels(accessToken: String) async throws -> GmailListLabelsResponse {
        try await get(baseURL.appendingPathComponent("labels"), accessToken: accessToken)
    }

    /// Add/remove label IDs — used for archive (remove INBOX), mark read/unread (remove/add UNREAD), etc.
    func modifyMessage(id: String, addLabelIds: [String] = [], removeLabelIds: [String] = [], accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("messages/\(id)/modify")
        let body: [String: Any] = [
            "addLabelIds": addLabelIds,
            "removeLabelIds": removeLabelIds,
        ]
        let _: EmptyResponse = try await post(url, body: body, accessToken: accessToken)
    }

    func trashMessage(id: String, accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("messages/\(id)/trash")
        let _: EmptyResponse = try await post(url, body: [:], accessToken: accessToken)
    }

    /// `rawRFC2822Base64URL` must be a base64url-encoded (not standard base64) RFC 2822 message.
    /// Requires the gmail.send scope in addition to gmail.readonly.
    func sendRawMessage(rawRFC2822Base64URL: String, accessToken: String) async throws {
        let url = baseURL.appendingPathComponent("messages/send")
        let body: [String: Any] = ["raw": rawRFC2822Base64URL]
        let _: EmptyResponse = try await post(url, body: body, accessToken: accessToken)
    }

    // MARK: - Low-level helpers

    private func get<T: Decodable>(_ url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ url: URL, body: [String: Any], accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GmailAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "unknown error"
            throw GmailAPIError.httpError(http.statusCode, message)
        }
    }
}
