//
//  guaperrimo_aiApp.swift
//  guaperrimo.ai
//
//  Created by Hermes Adan Aguilar Camacho on 3/4/26.
//

import SwiftUI
import Sentry


@main
struct guaperrimo_aiApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://b51fb00335f95666f9864ce5d6aaee22@o4511023805759488.ingest.us.sentry.io/4511023807791104"

            // Adds IP for users.
            // For more information, visit: https://docs.sentry.io/platforms/apple/data-management/data-collected/
            options.sendDefaultPii = true

            // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
            // We recommend adjusting this value in production.
            options.tracesSampleRate = 1.0

            // Configure profiling. Visit https://docs.sentry.io/platforms/apple/profiling/ to learn more.
            options.configureProfiling = {
                $0.sessionSampleRate = 1.0 // We recommend adjusting this value in production.
                $0.lifecycle = .trace
            }

            // Uncomment the following lines to add more data to your events
            // options.attachScreenshot = true // This adds a screenshot to the error events
            // options.attachViewHierarchy = true // This adds the view hierarchy to the error events
            
            // Enable experimental logging features
            options.experimental.enableLogs = true
        }
        // Remove the next line after confirming that your Sentry integration is working.
        SentrySDK.capture(message: "This app uses Sentry! :)")
    }
    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            #if DEBUG
            // Full flow: camera → conversation → style mirror (all via LiveStylistService)
            CameraView()
            #else
            CameraView()
            #endif
            #else
            ContentView()
            #endif
        }
    }
}
