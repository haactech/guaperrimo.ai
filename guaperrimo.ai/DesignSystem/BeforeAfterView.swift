//
//  BeforeAfterView.swift
//  guaperrimo.ai
//

import SwiftUI

/// Before/after comparison with a side-by-side and a slider mode.
struct BeforeAfterView: View {
    let beforeURL: URL?
    let afterURL: URL?

    enum Mode: Hashable { case sideBySide, slider }

    @State private var mode: Mode = .sideBySide
    @State private var sliderPosition: CGFloat = 0.5
    @State private var lastStep = 5
    private let haptic = UISelectionFeedbackGenerator()

    var body: some View {
        VStack(spacing: 0) {
            SegmentedControl(
                selection: $mode,
                options: [
                    (.sideBySide, String(localized: "tryon_mode_side")),
                    (.slider, String(localized: "tryon_mode_slider")),
                ]
            )
            .padding(.horizontal, 24)
            .padding(.bottom, DS.Space.m)

            switch mode {
            case .sideBySide: sideBySideView
            case .slider: sliderView
            }
        }
    }

    private func photo(_ url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.l).fill(DS.surfaceRaised)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))
    }

    private var sideBySideView: some View {
        HStack(spacing: DS.Space.s) {
            VStack(spacing: DS.Space.xs) {
                Text(String(localized: "tryon_before"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                photo(beforeURL)
            }
            VStack(spacing: DS.Space.xs) {
                Text(String(localized: "tryon_after"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS.textSecondary)
                photo(afterURL)
            }
        }
        .frame(maxHeight: 380)
        .padding(.horizontal, 24)
    }

    private var sliderView: some View {
        GeometryReader { geo in
            ZStack {
                photo(afterURL)

                photo(beforeURL)
                    .mask(
                        HStack {
                            Rectangle().frame(width: geo.size.width * sliderPosition)
                            Spacer(minLength: 0)
                        }
                    )

                ZStack {
                    Rectangle().fill(DS.textPrimary).frame(width: 2)
                    Circle()
                        .fill(DS.textPrimary)
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .overlay(
                            Image(systemName: "arrow.left.and.right")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(DS.bg)
                        )
                }
                .position(x: geo.size.width * sliderPosition, y: geo.size.height / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let clamped = max(0.02, min(0.98, value.location.x / geo.size.width))
                            sliderPosition = clamped
                            // Haptic only when crossing a 10% step.
                            let step = Int(clamped * 10)
                            if step != lastStep {
                                lastStep = step
                                haptic.selectionChanged()
                            }
                        }
                )
            }
        }
        .frame(maxHeight: 380)
        .padding(.horizontal, 24)
    }
}
