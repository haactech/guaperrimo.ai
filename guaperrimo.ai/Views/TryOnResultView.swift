//
//  TryOnResultView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct TryOnResultView: View {
    let action: PriorityAction
    let resultUrl: URL
    let userImageUrl: String
    let onDismiss: () -> Void

    enum CompareMode: String, CaseIterable {
        case sideBySide
        case slider
    }

    @State private var compareMode: CompareMode = .sideBySide
    @State private var sliderPosition: CGFloat = 0.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }

                    Spacer()

                    Text(String(localized: "tryon_title"))
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Mode picker
                Picker("", selection: $compareMode) {
                    Text(String(localized: "tryon_mode_side")).tag(CompareMode.sideBySide)
                    Text(String(localized: "tryon_mode_slider")).tag(CompareMode.slider)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // Comparison area
                switch compareMode {
                case .sideBySide:
                    sideBySideView
                case .slider:
                    sliderView
                }

                // Action info
                VStack(spacing: 4) {
                    Text(action.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(action.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Done button
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDismiss()
                } label: {
                    Text(String(localized: "tryon_done"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Side by side

    private var sideBySideView: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Text(String(localized: "tryon_before"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                AsyncImage(url: URL(string: userImageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(spacing: 8) {
                Text(String(localized: "tryon_after"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
                AsyncImage(url: resultUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxHeight: 380)
        .padding(.horizontal, 24)
    }

    // MARK: - Slider

    private var sliderView: some View {
        GeometryReader { geo in
            ZStack {
                // After image (full width, underneath)
                AsyncImage(url: resultUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    default:
                        Color.white.opacity(0.08)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Before image (masked to left of handle)
                AsyncImage(url: URL(string: userImageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    default:
                        Color.white.opacity(0.12)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .mask(
                    HStack {
                        Rectangle()
                            .frame(width: geo.size.width * sliderPosition)
                        Spacer(minLength: 0)
                    }
                )

                // Handle
                ZStack {
                    Rectangle()
                        .fill(.white)
                        .frame(width: 2)

                    Circle()
                        .fill(.white)
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.black)
                        )
                }
                .position(x: geo.size.width * sliderPosition, y: geo.size.height / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let clamped = max(0.02, min(0.98, value.location.x / geo.size.width))
                            sliderPosition = clamped
                        }
                )
            }
        }
        .frame(maxHeight: 380)
        .padding(.horizontal, 24)
    }
}
#endif
