//
//  LookCarouselView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct LookCarouselView: View {
    @Bindable var viewModel: ConversationViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                // Carousel
                TabView(selection: $viewModel.currentLookIndex) {
                    ForEach(Array(viewModel.lookItems.enumerated()), id: \.element.id) { index, look in
                        LookCardView(
                            look: look,
                            originalImageUrl: viewModel.userImageUrl,
                            onCompare: {
                                viewModel.showComparison = true
                            },
                            onPieces: {
                                viewModel.showPieceDetail = true
                            },
                            onRetry: {
                                viewModel.retryLook(at: index)
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .onChange(of: viewModel.currentLookIndex) { _, _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
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
                LookPieceSheet(pieces: look.pieces, onSave: { viewModel.saveLook(look) })
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                viewModel.closeLookCarousel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1), in: Circle())
            }

            Spacer()

            Text(String(localized: "looks_carousel_title"))
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Text("\(viewModel.readyLooksCount)/\(viewModel.totalLooksCount)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}
#endif
