//
//  ChatRequestEncodingTests.swift
//  guaperrimo.aiTests
//
//  The backend reads `location: {lat, lng, label}` on any turn (snake_case).

import Foundation
import Testing

@testable import guaperrimo_ai

@Suite struct ChatRequestEncodingTests {

    private func encode(_ request: ChatRequest) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func locationIsSentWithTheDeviceFields() throws {
        var request = ChatRequest(type: "button_response", imageUrl: nil, optionId: "boda", transcript: nil)
        request.location = DeviceLocation(lat: 19.4194, lng: -99.1616, label: "Roma Norte, Ciudad de México")
        let json = try encode(request)
        let location = try #require(json["location"] as? [String: Any])
        #expect(location["lat"] as? Double == 19.4194)
        #expect(location["lng"] as? Double == -99.1616)
        #expect(location["label"] as? String == "Roma Norte, Ciudad de México")
        #expect(json["option_id"] as? String == "boda")
    }

    @Test func locationIsOmittedWhenUnknown() throws {
        let json = try encode(ChatRequest(type: "image", imageUrl: "https://x/y.jpg", optionId: nil, transcript: nil))
        #expect(json["location"] == nil)
        #expect(json["image_url"] as? String == "https://x/y.jpg")
    }
}
