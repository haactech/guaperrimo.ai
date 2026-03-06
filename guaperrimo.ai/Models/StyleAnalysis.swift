//
//  StyleAnalysis.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

struct StyleAnalysisOption: Codable, Sendable {
    let id: String
    let title: String
    let description: String
}

struct StyleAnalysis: Codable, Sendable {
    let message: String
    let options: [StyleAnalysisOption]
}
#endif
