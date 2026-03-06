//
//  StylistService.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

protocol StylistService: Sendable {
    func analyzePhoto(sessionId: String) async throws -> StyleAnalysis
    func sendMessage(sessionId: String, userMessage: String) async throws -> StyleAnalysis
}

struct StubStylistService: StylistService {
    func analyzePhoto(sessionId: String) async throws -> StyleAnalysis {
        try await Task.sleep(for: .seconds(2))
        return StyleAnalysis(
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
