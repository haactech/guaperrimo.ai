//
//  guaperrimo_aiApp.swift
//  guaperrimo.ai
//
//  Created by Hermes Adan Aguilar Camacho on 3/4/26.
//

import SwiftUI

@main
struct guaperrimo_aiApp: App {
    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            #if DEBUG
            // Debug: skip photo flow, jump straight to conversation
            let debugSessionId: String? = "EECBB890-5690-485A-B272-1C6A85CCC858"
            if let sessionId = debugSessionId {
                ConversationView(sessionId: sessionId)
            } else {
                CameraView()
            }
            #else
            CameraView()
            #endif
            #else
            ContentView()
            #endif
        }
    }
}
