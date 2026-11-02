//
//  OnboardingView.swift
//  guaperrimo.ai
//
//  Three pages shown before the camera the first time, and again from the
//  camera's help button: what the app does, how to place the phone, and the
//  automatic capture.
//

#if os(iOS)
import SwiftUI

struct OnboardingView: View {
    static let seenKey = "hasSeenCameraOnboarding"

    var startPage: Int = 0
    let onFinish: () -> Void

    @State private var page: Int
    private let pageCount = 3

    init(startPage: Int = 0, onFinish: @escaping () -> Void) {
        self.startPage = startPage
        self.onFinish = onFinish
        _page = State(initialValue: min(max(startPage, 0), 2))
    }

    var body: some View {
        ZStack {
            TexturedBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < pageCount - 1 {
                        TertiaryButton(title: String(localized: "onb_skip"), action: finish)
                    } else {
                        Color.clear.frame(width: DS.minTap, height: DS.minTap)
                    }
                }
                .padding(.horizontal, DS.Space.m)
                .padding(.top, DS.Space.xs)

                TabView(selection: $page) {
                    OnboardingPage(
                        title: String(localized: "onb1_title"),
                        text: String(localized: "onb1_body")
                    ) { WhatWeDoIllustration(isActive: page == 0) }
                    .tag(0)

                    OnboardingPage(
                        title: String(localized: "onb2_title"),
                        text: String(localized: "onb2_body")
                    ) { PlacementIllustration(isActive: page == 1) }
                    .tag(1)

                    OnboardingPage(
                        title: String(localized: "onb3_title"),
                        text: String(localized: "onb3_body")
                    ) { AutoCaptureIllustration(isActive: page == 2) }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: page)

                PageDots(count: pageCount, current: page)
                    .padding(.bottom, DS.Space.m)

                PrimaryButton(
                    title: page < pageCount - 1 ? String(localized: "onb_next") : String(localized: "onb_open_camera"),
                    systemImage: page < pageCount - 1 ? nil : "camera"
                ) {
                    if page < pageCount - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
                    } else {
                        finish()
                    }
                }
                .padding(.horizontal, DS.Space.inset)
                .padding(.bottom, DS.Space.l)
            }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)
        onFinish()
    }
}

private struct OnboardingPage<Illustration: View>: View {
    let title: String
    let text: String
    @ViewBuilder var illustration: Illustration

    var body: some View {
        VStack(spacing: DS.Space.l) {
            Spacer(minLength: 0)
            illustration
                .frame(height: 280)
                .frame(maxWidth: .infinity)
            VStack(spacing: DS.Space.s) {
                Text(title)
                    .font(DS.Font.display)
                    .foregroundStyle(DS.textPrimary)
                    .multilineTextAlignment(.center)
                Text(text)
                    .font(.body)
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, DS.Space.xl)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.m)
    }
}

/// Page indicator: a short tape mark for the current page, dots for the rest.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? DS.accent : DS.strokeStrong)
                    .frame(width: index == current ? 22 : 6, height: 6)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "onb_page_of"), current + 1, count))
    }
}
#endif
