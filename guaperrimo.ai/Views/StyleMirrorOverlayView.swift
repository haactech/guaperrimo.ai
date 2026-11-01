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
    let isSaved: Bool
    let onClose: () -> Void
    let onCompare: () -> Void
    let onPieces: () -> Void
    let onList: () -> Void
    let onSave: () -> Void

    @State private var showSavedToast = false

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
                    HStack(spacing: DS.Space.xs) {
                        IconButton(
                            systemName: isSaved ? "heart.fill" : "heart",
                            accessibilityLabel: String(localized: isSaved ? "mylooks_saved_label" : "mylooks_save_label"),
                            action: save
                        )
                        IconButton(
                            systemName: "square.split.2x1",
                            accessibilityLabel: String(localized: "tryon_mode_side"),
                            action: onCompare
                        )
                    }
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
                            .foregroundStyle(DS.stroke)
                            .padding(.leading, 8)
                    }
                    Spacer()
                    if currentIndex < totalCount - 1 {
                        Image(systemName: "chevron.right")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(DS.stroke)
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
                                .fill(index == currentIndex ? DS.textPrimary : DS.textTertiary)
                                .frame(width: index == currentIndex ? 8 : 6,
                                       height: index == currentIndex ? 8 : 6)
                                .animation(.easeInOut(duration: 0.2), value: currentIndex)
                        }
                    }
                }

                // "See garments" button (only for looks, not original)
                if !isOriginal {
                    SecondaryButton(title: String(localized: "looks_pieces"), action: onPieces)
                }
            }
            .padding(.bottom, 40)
            .opacity(overlayOpacity)
        }
        .overlay(alignment: .top) {
            if showSavedToast {
                Toast(message: String(localized: "mylooks_saved_toast"))
                    .padding(.top, 72)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.15), value: overlayOpacity < 1.0)
        .animation(.easeInOut(duration: 0.2), value: showSavedToast)
    }

    private func save() {
        onSave()
        showSavedToast = true
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            showSavedToast = false
        }
    }
}
#endif
