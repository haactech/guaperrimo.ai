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
    let onClose: () -> Void
    let onCompare: () -> Void
    let onPieces: () -> Void
    let onList: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1), in: Circle())
                }

                Button(action: onList) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .accessibilityLabel(String(localized: "shopping_title"))

                Spacer()

                Text(itemName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                if !isOriginal {
                    Button(action: onCompare) {
                        Image(systemName: "square.split.2x1")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .opacity(overlayOpacity)

            Spacer()

            // Swipe hints (translucent arrows at edges) — always visible during focus mode
            if showHints && totalCount > 1 {
                HStack {
                    if currentIndex > 0 {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.leading, 8)
                    }
                    Spacer()
                    if currentIndex < totalCount - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
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
                        .foregroundStyle(.white.opacity(0.6))
                        .transition(.opacity)
                }

                // Pagination dots
                if totalCount > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<totalCount, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                                .frame(width: index == currentIndex ? 8 : 6,
                                       height: index == currentIndex ? 8 : 6)
                                .animation(.easeInOut(duration: 0.2), value: currentIndex)
                        }
                    }
                }

                // "See garments" button (only for looks, not original)
                if !isOriginal {
                    Button(action: onPieces) {
                        Text(String(localized: "looks_pieces"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
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
