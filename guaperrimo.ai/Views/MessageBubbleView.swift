//
//  MessageBubbleView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct MessageBubbleView: View {
    let message: ConversationMessage
    var onSelectOption: ((StyleOption) -> Void)?

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .stylist ? .leading : .trailing, spacing: 10) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground, in: bubbleShape)

                if !message.options.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(message.options) { option in
                            StyleOptionCardView(option: option) {
                                onSelectOption?(option)
                            }
                        }
                    }
                }
            }

            if message.role == .stylist { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }

    private var bubbleBackground: Color {
        message.role == .stylist ? Color.white.opacity(0.15) : Color.green.opacity(0.6)
    }

    private var bubbleShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16)
    }
}
#endif
