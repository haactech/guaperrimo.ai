//
//  APIClient.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation
import OSLog
import UIKit

private let logger = Logger(subsystem: "ai.guaperrimo", category: "APIClient")

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case encodingFailed
    case decodingFailed(underlying: Error, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .serverError(let code, let message): return "Server error \(code): \(message)"
        case .encodingFailed: return "Failed to encode image"
        case .decodingFailed(_, let body): return "Failed to decode response: \(body)"
        }
    }
}

struct APIClient: Sendable {
    #if DEBUG
    static let baseURL = "http://192.168.100.39:8080"
    #else
    static let baseURL = "http://192.168.100.39:8080" // TODO: production URL
    #endif

    func postJSON<TBody: Encodable, TResponse: Decodable & Sendable>(
        path: String,
        body: TBody,
        timeout: TimeInterval = 60
    ) async throws -> TResponse {
        guard let url = URL(string: "\(Self.baseURL)\(path)") else {
            logger.error("Invalid URL: \(Self.baseURL, privacy: .public)\(path, privacy: .public)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let bodyString = String(data: request.httpBody!, encoding: .utf8) ?? ""
        logger.info("⬆️ POST \(url.absoluteString, privacy: .public) — \(bodyString, privacy: .public)")

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let responseBody = String(data: responseData, encoding: .utf8) ?? "<binary \(responseData.count) bytes>"
        logger.info("⬇️ HTTP \(httpResponse.statusCode, privacy: .public) — \(responseBody, privacy: .public)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: responseBody)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(TResponse.self, from: responseData)
        } catch {
            logger.error("❌ Decode error: \(String(describing: error), privacy: .public) — body: \(responseBody, privacy: .public)")
            throw APIError.decodingFailed(underlying: error, body: responseBody)
        }
    }

    func getJSON<TResponse: Decodable & Sendable>(
        path: String,
        timeout: TimeInterval = 30
    ) async throws -> TResponse {
        guard let url = URL(string: "\(Self.baseURL)\(path)") else {
            logger.error("Invalid URL: \(Self.baseURL, privacy: .public)\(path, privacy: .public)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout

        logger.info("⬆️ GET \(url.absoluteString, privacy: .public)")

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let responseBody = String(data: responseData, encoding: .utf8) ?? "<binary \(responseData.count) bytes>"
        logger.info("⬇️ HTTP \(httpResponse.statusCode, privacy: .public) — \(responseBody, privacy: .public)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: responseBody)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(TResponse.self, from: responseData)
        } catch {
            logger.error("❌ Decode error: \(String(describing: error), privacy: .public) — body: \(responseBody, privacy: .public)")
            throw APIError.decodingFailed(underlying: error, body: responseBody)
        }
    }

    func uploadMultipart<T: Decodable & Sendable>(
        path: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data
    ) async throws -> T {
        guard let url = URL(string: "\(Self.baseURL)\(path)") else {
            logger.error("Invalid URL: \(Self.baseURL, privacy: .public)\(path, privacy: .public)")
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")

        request.httpBody = body

        logger.info("⬆️ POST \(url.absoluteString, privacy: .public) (\(body.count, privacy: .public) bytes)")

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("❌ Network error: \(String(describing: error), privacy: .public)")
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ Response is not HTTPURLResponse")
            throw APIError.invalidResponse
        }

        let responseBody = String(data: responseData, encoding: .utf8) ?? "<binary \(responseData.count) bytes>"
        logger.info("⬇️ HTTP \(httpResponse.statusCode, privacy: .public) — \(responseBody, privacy: .public)")

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("❌ Server error \(httpResponse.statusCode, privacy: .public): \(responseBody, privacy: .public)")
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: responseBody)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: responseData)
        } catch {
            logger.error("❌ Decode error: \(String(describing: error), privacy: .public) — body: \(responseBody, privacy: .public)")
            throw APIError.decodingFailed(underlying: error, body: responseBody)
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
#endif
