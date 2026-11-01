//
//  ConversationHistoryView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

/// The conversation so far: stylist lines on the left, the user's answers on the right.
struct ConversationHistoryView: View {
    let entries: [ConversationEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            TexturedBackground()

            VStack(spacing: 0) {
                HStack {
                    HeaderSpacer()
                    Spacer()
                    Text(String(localized: "history_title"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    IconButton(systemName: "xmark", accessibilityLabel: String(localized: "preview_close")) {
                        dismiss()
                    }
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.top, DS.Space.xs)
                .padding(.bottom, DS.Space.s)

                ScrollView {
                    LazyVStack(spacing: DS.Space.s) {
                        ForEach(entries) { entry in
                            row(entry)
                        }
                    }
                    .padding(.horizontal, DS.Space.m)
                    .padding(.vertical, DS.Space.s)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func row(_ entry: ConversationEntry) -> some View {
        let isUser = entry.role == .user
        return HStack {
            if isUser { Spacer(minLength: DS.Space.xl) }
            Text(entry.text)
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(isUser ? .trailing : .leading)
                .padding(.horizontal, DS.Space.m)
                .padding(.vertical, DS.Space.s)
                .background(
                    isUser ? DS.surfaceRaised : DS.surface,
                    in: RoundedRectangle(cornerRadius: DS.Radius.m)
                )
            if !isUser { Spacer(minLength: DS.Space.xl) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
#endif
