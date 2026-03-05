//
//  ImageUploadService.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation
import OSLog
import UIKit

private let logger = Logger(subsystem: "ai.guaperrimo", category: "ImageUpload")

struct ImageUploadService: Sendable {
    private let apiClient = APIClient()

    func upload(image: UIImage, sessionId: String, compressionQuality: CGFloat = 0.85) async throws -> UploadResponse {
        logger.info("📸 Encoding image \(Int(image.size.width))x\(Int(image.size.height)) as JPEG (q=\(compressionQuality))")

        guard let jpegData = image.jpegData(compressionQuality: compressionQuality) else {
            logger.error("❌ Failed to encode UIImage to JPEG")
            throw APIError.encodingFailed
        }

        logger.info("📦 JPEG size: \(jpegData.count) bytes (\(jpegData.count / 1024) KB) — session: \(sessionId)")

        let response: UploadResponse = try await apiClient.uploadMultipart(
            path: "/session/\(sessionId)/image",
            fieldName: "image",
            fileName: "outfit.jpg",
            mimeType: "image/jpeg",
            data: jpegData
        )

        logger.info("✅ Upload OK — session: \(response.sessionId), url: \(response.url)")
        return response
    }
}
#endif
