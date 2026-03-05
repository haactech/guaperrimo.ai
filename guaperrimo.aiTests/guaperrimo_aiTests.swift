//
//  guaperrimo_aiTests.swift
//  guaperrimo.aiTests
//

import Foundation
import Testing

@testable import guaperrimo_ai

// MARK: - Multipart body construction tests

@Suite struct MultipartBodyTests {

    @Test func multipartBodyContainsCorrectStructure() throws {
        let boundary = "test-boundary-123"
        let imageData = Data("fakejpeg".utf8)

        let body = buildMultipartBody(
            boundary: boundary,
            fieldName: "image",
            fileName: "outfit.jpg",
            mimeType: "image/jpeg",
            data: imageData
        )

        let bodyString = try #require(String(data: body, encoding: .utf8))

        #expect(bodyString.contains("--test-boundary-123"))
        #expect(bodyString.contains("Content-Disposition: form-data; name=\"image\"; filename=\"outfit.jpg\""))
        #expect(bodyString.contains("Content-Type: image/jpeg"))
        #expect(bodyString.contains("--test-boundary-123--"))
    }

    @Test func multipartBodyContainsImageData() {
        let boundary = "test-boundary"
        let imageData = Data(repeating: 0xAB, count: 256)

        let body = buildMultipartBody(
            boundary: boundary,
            fieldName: "image",
            fileName: "test.jpg",
            mimeType: "image/jpeg",
            data: imageData
        )

        #expect(body.range(of: imageData) != nil)
    }
}

// MARK: - UploadResponse decoding tests

@Suite struct UploadResponseTests {

    @Test func decodesSnakeCaseJSON() throws {
        let json = """
        {"session_id": "abc-123", "url": "https://r2.example.com/outfits/abc.jpg"}
        """
        let data = Data(json.utf8)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(UploadResponse.self, from: data)

        #expect(response.sessionId == "abc-123")
        #expect(response.url == "https://r2.example.com/outfits/abc.jpg")
    }

    @Test func failsOnMissingFields() {
        let json = """
        {"session_id": "abc-123"}
        """
        let data = Data(json.utf8)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(UploadResponse.self, from: data)
        }
    }
}

// MARK: - Image encoding tests (requires UIKit)

#if os(iOS)
import UIKit

@MainActor
@Suite struct ImageEncodingTests {

    @Test func jpegEncodingProducesValidData() throws {
        let image = createTestImage(width: 100, height: 100, color: .red)
        let data = try #require(image.jpegData(compressionQuality: 0.85))

        #expect(data.count > 0)
        #expect(data[0] == 0xFF)
        #expect(data[1] == 0xD8)
        #expect(data[2] == 0xFF)
    }

    @Test func jpegCompressionReducesSize() throws {
        let image = createTestImage(width: 500, height: 500, color: .blue)
        let highQuality = try #require(image.jpegData(compressionQuality: 1.0))
        let lowQuality = try #require(image.jpegData(compressionQuality: 0.1))

        #expect(lowQuality.count < highQuality.count)
    }

    @Test func largeImageProducesDataUnder10MB() throws {
        let image = createTestImage(width: 1920, height: 1080, color: .green)
        let data = try #require(image.jpegData(compressionQuality: 0.85))

        let tenMB = 10 * 1024 * 1024
        #expect(data.count < tenMB, "JPEG should be under 10MB limit, got \(data.count) bytes")
    }

    private func createTestImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
#endif

// MARK: - Helpers

private func buildMultipartBody(
    boundary: String,
    fieldName: String,
    fileName: String,
    mimeType: String,
    data: Data
) -> Data {
    var body = Data()
    body.append(Data("--\(boundary)\r\n".utf8))
    body.append(Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".utf8))
    body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
    body.append(data)
    body.append(Data("\r\n--\(boundary)--\r\n".utf8))
    return body
}
