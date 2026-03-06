//
//  ConversationInputBar.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct ConversationInputBar: View {
    @Binding var text: String
    let isListening: Bool
    let onSend: () -> Void
    let onMicTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Mic button
            Button(action: onMicTap) {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.system(size: 20))
                    .foregroundStyle(isListening ? .red : .white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(isListening ? Color.red.opacity(0.2) : Color.white.opacity(0.12))
                    )
            }

            // Text field
            TextField(String(localized: "type_message"), text: $text)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1), in: Capsule())
                .tint(.white)

            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? .white : .white.opacity(0.3))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
#endif
