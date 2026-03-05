//
//  UploadResponse.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

nonisolated struct UploadResponse: Codable, Sendable {
    let sessionId: String
    let url: String
}
#endif
