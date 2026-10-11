//
//  TryOnLoadingView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI
internal import Combine

struct TryOnLoadingView: View {
    let action: PriorityAction
    let userImageUrl: String
    let onCancel: () -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var shimmerPhase: CGFloat = -1

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var progress: Double {
        min(1 - exp(-elapsed / 10), 0.95)
    }

    private var statusText: String {
        if elapsed < 3 {
            return String(localized: "tryon_progress_1")
        } else if elapsed < 6 {
            return String(localized: "tryon_progress_2")
        } else if elapsed < 10 {
            return String(localized: "tryon_progress_3")
        } else {
            return String(localized: "tryon_progress_4")
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // User photo with shimmer overlay
                AsyncImage(url: URL(string: userImageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(shimmerOverlay)
                    default:
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 360)
                            .overlay(shimmerOverlay)
                    }
                }
                .padding(.horizontal, 40)

                // Status text
                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .animation(.easeInOut, value: statusText)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                            .animation(.easeOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 48)

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()

                Spacer()

                // Cancel button
                Button {
                    onCancel()
                } label: {
                    Text(String(localized: "tryon_cancel"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
                .padding(.bottom, 32)
            }
        }
        .onReceive(timer) { _ in
            elapsed += 0.1
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 2
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    .white.opacity(0),
                    .white.opacity(0.15),
                    .white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.6)
            .offset(x: geo.size.width * shimmerPhase)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
#endif
