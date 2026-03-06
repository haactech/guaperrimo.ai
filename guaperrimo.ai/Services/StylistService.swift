//
//  StylistService.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation
import OSLog

private let logger = Logger(subsystem: "ai.guaperrimo", category: "StylistService")

// MARK: - Protocol

protocol StylistService: Sendable {
    func analyzePhoto(sessionId: String) async throws -> StyleAnalysis
    func sendMessage(sessionId: String, userMessage: String) async throws -> StyleAnalysis
}

// MARK: - Errors

enum StylistError: Error, LocalizedError {
    case noImageFound
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .noImageFound:
            return "No image found for this session. Please retake the photo."
        case .serverError(let message):
            return "Style analysis failed: \(message)"
        }
    }
}

// MARK: - Live implementation

struct LiveStylistService: StylistService {
    private let baseURL = APIClient.baseURL
    private let stubForChat = StubStylistService()

    func analyzePhoto(sessionId: String) async throws -> StyleAnalysis {
        let url = URL(string: "\(baseURL)/session/\(sessionId)/analyze")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180

        logger.info("⬆️ POST /session/\(sessionId)/analyze")

        let (data, response) = try await URLSession.shared.data(for: request)

        let httpResponse = response as! HTTPURLResponse
        let responseBody = String(data: data, encoding: .utf8) ?? "<binary \(data.count) bytes>"
        logger.info("⬇️ HTTP \(httpResponse.statusCode) — \(responseBody)")

        if httpResponse.statusCode == 404 {
            throw StylistError.noImageFound
        }

        if httpResponse.statusCode != 200 {
            let errorBody = try? JSONDecoder().decode([String: String].self, from: data)
            throw StylistError.serverError(errorBody?["error"] ?? "Unknown error")
        }

        return try JSONDecoder().decode(StyleAnalysis.self, from: data)
    }

    func sendMessage(sessionId: String, userMessage: String) async throws -> StyleAnalysis {
        // No backend endpoint yet — delegate to stub
        return try await stubForChat.sendMessage(sessionId: sessionId, userMessage: userMessage)
    }
}

// MARK: - Stub implementation

struct StubStylistService: StylistService {
    func analyzePhoto(sessionId: String) async throws -> StyleAnalysis {
        try await Task.sleep(for: .seconds(2))
        return StyleAnalysis(
            analysis: "Veo una camiseta negra de corte regular con un logo discreto, combinada con shorts de denim gris oscuro. El look es casual y relajado, perfecto para el día a día. Las proporciones son buenas y el contraste oscuro arriba con el denim abajo funciona bien.",
            message: "I can see you're going for a relaxed, comfortable look today. The fit is casual but put-together — I like it! Let me help you take it to the next level. What vibe are you going for?",
            options: [
                StyleAnalysisOption(id: "casual_elevated", title: "Casual Elevated", description: "Keep it comfy but add polish"),
                StyleAnalysisOption(id: "streetwear", title: "Streetwear", description: "Bold, urban, statement pieces"),
                StyleAnalysisOption(id: "minimalist", title: "Minimalist", description: "Clean lines, neutral tones"),
                StyleAnalysisOption(id: "smart_casual", title: "Smart Casual", description: "Ready for drinks or a date"),
            ]
        )
    }

    func sendMessage(sessionId: String, userMessage: String) async throws -> StyleAnalysis {
        try await Task.sleep(for: .seconds(1.5))
        return StyleAnalysis(
            analysis: nil,
            message: "Great choice! Based on your outfit and style preference, I'd suggest swapping those sneakers for something with a bit more structure. A pair of clean leather boots or minimal white sneakers would tie everything together. Want me to suggest specific pieces?",
            options: [
                StyleAnalysisOption(id: "show_shoes", title: "Show me shoes", description: "Footwear recommendations"),
                StyleAnalysisOption(id: "show_tops", title: "Show me tops", description: "Upper body alternatives"),
                StyleAnalysisOption(id: "full_outfit", title: "Full outfit idea", description: "Complete look suggestion"),
                StyleAnalysisOption(id: "keep_current", title: "I like my current look", description: "Tips to enhance what you have"),
            ]
        )
    }
}
#endif
