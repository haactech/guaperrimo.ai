//
//  StyleMirrorView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI
import UIKit

struct StyleMirrorView: View {
    @Bindable var viewModel: ConversationViewModel

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showHints = true
    @State private var preloadedImages: [String: UIImage] = [:]
    @State private var downloadingHint: String? = nil

    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let impactHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)

    @State private var didPassHalf = false

    // MARK: - Easing function (smoothstep: ease-in-out)

    private func eased(_ t: CGFloat) -> CGFloat {
        t * t * (3.0 - 2.0 * t)
    }

    var body: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let canvasHeight = geo.size.height * 0.8
            let items = viewModel.mirrorItems
            let currentItem = items.indices.contains(viewModel.currentLookIndex)
                ? items[viewModel.currentLookIndex] : nil

            let linearProgress = items.count > 1
                ? min(abs(dragOffset) / (screenWidth * 0.4), 1.0)
                : CGFloat(0)

            let progress = eased(linearProgress)

            let neighborIdx = neighborIndex(for: items.count, current: viewModel.currentLookIndex)

            // Overlay fades out quickly during drag, returns with spring
            let overlayOpacity = 1.0 - min(Double(linearProgress) * 3.0, 1.0)

            ZStack {
                Color.black.ignoresSafeArea()
                StyleMirrorBackgroundView()

                // Canvas (centered)
                VStack {
                    Spacer()
                    StyleMirrorCanvasView(
                        currentImage: currentItem.flatMap { imageFor($0) },
                        neighborImage: neighborIdx.flatMap { imageFor(items[$0]) },
                        crossfadeProgress: progress,
                        isLoading: false // Never show shimmer during crossfade
                    )
                    .frame(height: canvasHeight)
                    Spacer()
                }

                // Overlay (top bar + bottom)
                VStack(spacing: 0) {
                    Spacer().frame(height: 0)

                    StyleMirrorOverlayView(
                        itemName: currentItem?.name ?? String(localized: "mirror_title"),
                        isOriginal: currentItem?.isOriginal ?? true,
                        currentIndex: viewModel.currentLookIndex,
                        totalCount: items.count,
                        showHints: showHints,
                        overlayOpacity: overlayOpacity,
                        downloadingHint: downloadingHint,
                        onClose: { viewModel.closeLookCarousel() },
                        onCompare: { viewModel.showComparison = true },
                        onPieces: { viewModel.showPieceDetail = true }
                    )
                }
            }
            .gesture(
                items.count > 1
                    ? DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            let idx = viewModel.currentLookIndex

                            // Check if neighbor image is ready
                            let neighborReady = isNeighborImageReady(
                                items: items, current: idx, translation: translation
                            )

                            // Boundary resistance: edges OR neighbor image not downloaded
                            let atBoundary = (idx == 0 && translation > 0)
                                || (idx == items.count - 1 && translation < 0)
                                || !neighborReady

                            if atBoundary {
                                dragOffset = translation * 0.2

                                // Show downloading hint when blocked by missing image
                                if !neighborReady && !atEdge(idx: idx, count: items.count, translation: translation) {
                                    downloadingHint = String(localized: "mirror_generating")
                                }
                            } else {
                                dragOffset = translation
                                downloadingHint = nil
                            }

                            isDragging = true

                            // Haptic at 50%
                            let currentProgress = min(abs(dragOffset) / (screenWidth * 0.4), 1.0)
                            if currentProgress >= 0.5 && !didPassHalf {
                                didPassHalf = true
                                selectionHaptic.selectionChanged()
                            } else if currentProgress < 0.5 {
                                didPassHalf = false
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            let shouldSnap = abs(dragOffset) > 80 || abs(velocity) > 200
                            let idx = viewModel.currentLookIndex

                            // Only snap if neighbor image is actually ready
                            let neighborReady = isNeighborImageReady(
                                items: items, current: idx, translation: dragOffset
                            )

                            if shouldSnap && neighborReady {
                                if dragOffset > 0 && idx > 0 {
                                    impactHaptic.impactOccurred()
                                    viewModel.currentLookIndex = idx - 1
                                    showHints = false
                                } else if dragOffset < 0 && idx < items.count - 1 {
                                    impactHaptic.impactOccurred()
                                    viewModel.currentLookIndex = idx + 1
                                    showHints = false
                                } else {
                                    rigidHaptic.impactOccurred()
                                }
                            } else if shouldSnap {
                                // Tried to snap but image not ready
                                rigidHaptic.impactOccurred()
                            }

                            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                dragOffset = 0
                            }
                            isDragging = false
                            didPassHalf = false
                            downloadingHint = nil
                        }
                    : nil
            )
        }
        .task(id: viewModel.mirrorItems.map(\.id)) {
            await preloadAllImages()
        }
        .fullScreenCover(isPresented: $viewModel.showComparison) {
            if let look = viewModel.currentLook, look.status == "ready" {
                LookComparisonView(
                    look: look,
                    originalImageUrl: viewModel.userImageUrl,
                    onDismiss: { viewModel.showComparison = false }
                )
            }
        }
        .sheet(isPresented: $viewModel.showPieceDetail) {
            if let look = viewModel.currentLook, !look.pieces.isEmpty {
                LookPieceSheet(pieces: look.pieces)
            }
        }
    }

    // MARK: - Helpers

    private func neighborIndex(for count: Int, current: Int) -> Int? {
        guard count > 1 else { return nil }
        if dragOffset < 0 && current < count - 1 {
            return current + 1
        } else if dragOffset > 0 && current > 0 {
            return current - 1
        }
        return nil
    }

    private func imageFor(_ item: StyleMirrorItem) -> UIImage? {
        guard let url = item.imageUrl else { return nil }
        return preloadedImages[url] ?? ImagePreloader.shared.cachedImage(for: url)
    }

    /// Check if the neighbor in the swipe direction has its image downloaded and ready.
    private func isNeighborImageReady(items: [StyleMirrorItem], current: Int, translation: CGFloat) -> Bool {
        let targetIndex: Int
        if translation < 0 && current < items.count - 1 {
            targetIndex = current + 1
        } else if translation > 0 && current > 0 {
            targetIndex = current - 1
        } else {
            return true // at edge, no neighbor to check
        }
        return imageFor(items[targetIndex]) != nil
    }

    /// True if translation pushes past the first/last item (real edge).
    private func atEdge(idx: Int, count: Int, translation: CGFloat) -> Bool {
        (idx == 0 && translation > 0) || (idx == count - 1 && translation < 0)
    }

    private func preloadAllImages() async {
        let urls = viewModel.mirrorItems.compactMap(\.imageUrl)
        await ImagePreloader.shared.preloadAll(urls)

        // Update local lookup for SwiftUI reactivity
        var updated: [String: UIImage] = [:]
        for url in urls {
            if let img = ImagePreloader.shared.cachedImage(for: url) {
                updated[url] = img
            }
        }
        preloadedImages = updated
    }
}
#endif
