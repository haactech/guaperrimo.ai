//
//  StyleMirrorOverlayView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct StyleMirrorOverlayView: View {
    let itemName: String
    let isOriginal: Bool
    let currentIndex: Int
    let totalCount: Int
    let showHints: Bool
    let overlayOpacity: Double
    let downloadingHint: String?
    var canAskOpinion: Bool = false
    let onClose: () -> Void
    let onCompare: () -> Void
    let onPieces: () -> Void
    let onList: () -> Void
    var onAskOpinion: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            ScreenHeader(title: itemName) {
                HStack(spacing: DS.Space.xs) {
                    IconButton(
                        systemName: "xmark",
                        accessibilityLabel: String(localized: "preview_close"),
                        action: onClose
                    )
                    IconButton(
                        systemName: "bag.fill",
                        accessibilityLabel: String(localized: "shopping_title"),
                        action: onList
                    )
                }
            } trailing: {
                if !isOriginal {
                    IconButton(
                        systemName: "square.split.2x1",
                        accessibilityLabel: String(localized: "tryon_mode_side"),
                        action: onCompare
                    )
                } else {
                    HeaderSpacer()
                }
            }
            .opacity(overlayOpacity)

            Spacer()

            // Swipe hints (translucent arrows at edges) — always visible during focus mode
            if showHints && totalCount > 1 {
                HStack {
                    if currentIndex > 0 {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(DS.textTertiary)
                            .padding(.leading, 8)
                    }
                    Spacer()
                    if currentIndex < totalCount - 1 {
                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(DS.textTertiary)
                            .padding(.trailing, 8)
                    }
                }
            }

            Spacer()

            // Bottom: Pagination dots + garments button + downloading hint
            VStack(spacing: 16) {
                // Downloading hint (shown when neighbor image not ready)
                if let hint = downloadingHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                        .transition(.opacity)
                }

                // Pagination dots
                if totalCount > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<totalCount, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? DS.accent : DS.stroke)
                                .frame(width: index == currentIndex ? 8 : 6,
                                       height: index == currentIndex ? 8 : 6)
                                .animation(.easeInOut(duration: 0.2), value: currentIndex)
                        }
                    }
                }

                // "See garments" (only for looks) and "ask for opinions" (two looks or more)
                HStack(spacing: DS.Space.xs) {
                    if !isOriginal {
                        SecondaryButton(title: String(localized: "looks_pieces"), action: onPieces)
                            .background(DS.bg.opacity(0.55), in: RoundedRectangle(cornerRadius: DS.Radius.button))
                    }
                    if canAskOpinion {
                        SecondaryButton(title: String(localized: "poll_ask_button"), systemImage: "person.2", action: onAskOpinion)
                            .background(DS.bg.opacity(0.55), in: RoundedRectangle(cornerRadius: DS.Radius.button))
                    }
                }
            }
            .padding(.bottom, 40)
            .opacity(overlayOpacity)
        }
        .animation(.easeOut(duration: 0.15), value: overlayOpacity < 1.0)
    }
}
#endif
