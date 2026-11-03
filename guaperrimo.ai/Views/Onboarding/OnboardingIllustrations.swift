//
//  OnboardingIllustrations.swift
//  guaperrimo.ai
//
//  Three small animated scenes drawn with the design system: what the app
//  does, how to place the phone, and the automatic capture. Each one plays
//  when `isActive` turns true and honours Reduce Motion.
//

#if os(iOS)
import SwiftUI

// MARK: - Shared bits

/// A tailor's tape: baseline with ticks, every fifth one taller. Drawn left to right.
struct TapeLine: Shape {
    var ticks: Int = 24
    var progress: CGFloat = 1

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let end = rect.minX + rect.width * progress
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: end, y: rect.midY))
        for i in 0...ticks {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(ticks)
            guard x <= end else { break }
            let h = i % 5 == 0 ? rect.height * 0.5 : rect.height * 0.25
            path.move(to: CGPoint(x: x, y: rect.midY))
            path.addLine(to: CGPoint(x: x, y: rect.midY + h))
        }
        return path
    }
}

private struct MonoTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(DS.Font.monoSmall.weight(.medium))
            .foregroundStyle(DS.textPrimary)
            .padding(.horizontal, DS.Space.xs)
            .padding(.vertical, DS.Space.xxs)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.s))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.s).stroke(DS.stroke, lineWidth: 1))
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(DS.Space.s)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.m).stroke(DS.stroke, lineWidth: 1))
    }
}

// MARK: - 1 · What we do

/// Photo → palette → outfit, three cards joined by a measuring tape.
struct WhatWeDoIllustration: View {
    let isActive: Bool
    @State private var shown = 0
    @State private var tape: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let swatches = ["#3E5641", "#B87D4F", "#D4A017", "#CC6B49", "#D4C4A6"]

    var body: some View {
        VStack(spacing: DS.Space.m) {
            HStack(alignment: .top, spacing: DS.Space.s) {
                step(index: 1, label: String(localized: "onb1_step_photo")) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.s).fill(DS.surfaceRaised)
                        BodyGuideShape()
                            .stroke(DS.textPrimary.opacity(0.8), lineWidth: 1.5)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                    }
                    .frame(width: 72, height: 96)
                }
                step(index: 2, label: String(localized: "onb1_step_palette")) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            ForEach(swatches.prefix(3), id: \.self) { swatch(swatch: $0) }
                        }
                        HStack(spacing: 4) {
                            ForEach(swatches.suffix(2), id: \.self) { swatch(swatch: $0) }
                        }
                    }
                    .frame(width: 72, height: 96)
                }
                step(index: 3, label: String(localized: "onb1_step_outfit")) {
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: DS.Radius.s)
                            .fill(DS.surfaceRaised)
                            .frame(height: 52)
                            .overlay(Image(systemName: "tshirt").foregroundStyle(DS.textTertiary))
                        Text("1,078 MXN")
                            .font(DS.Font.monoSmall.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                        Text("450 m")
                            .font(DS.Font.monoSmall)
                            .foregroundStyle(DS.accent)
                    }
                    .frame(width: 72, height: 96, alignment: .top)
                }
            }

            TapeLine(ticks: 30, progress: tape)
                .stroke(DS.strokeStrong, lineWidth: 1)
                .frame(height: 16)
                .overlay(alignment: .leading) {
                    Rectangle().fill(DS.accent).frame(height: 2)
                        .scaleEffect(x: tape, anchor: .leading)
                        .offset(y: 0)
                }
                .padding(.horizontal, DS.Space.l)
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active { play() } else { reset() }
        }
    }

    private func swatch(swatch hex: String) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(hex: hex))
            .frame(width: 20, height: 20)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(DS.stroke, lineWidth: 1))
    }

    private func step<Content: View>(index: Int, label: String, @ViewBuilder content: () -> Content) -> some View {
        let visible = shown >= index
        return VStack(spacing: DS.Space.xs) {
            Card { content() }
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.textSecondary)
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 14)
        .scaleEffect(visible ? 1 : 0.96)
    }

    private func play() {
        if reduceMotion { shown = 3; tape = 1; return }
        reset()
        for i in 1...3 {
            withAnimation(.spring(duration: 0.55, bounce: 0.25).delay(0.15 + Double(i - 1) * 0.35)) {
                shown = i
            }
        }
        withAnimation(.easeOut(duration: 1.1).delay(0.25)) { tape = 1 }
    }

    private func reset() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { shown = 0; tape = 0 }
    }
}

// MARK: - 2 · Placement

/// Side view: phone on a surface, you at 120 cm, two tapes with the numbers.
struct PlacementIllustration: View {
    let isActive: Bool
    @State private var figureIn = false
    @State private var tapes: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let floorY = h * 0.84
            let tableX = w * 0.26
            let tableW = w * 0.14
            let tableTop = h * 0.50          // ≈ 105 cm on this scale
            let figureX = w * 0.80
            let figureH = h * 0.76           // ≈ 175 cm
            let figureW = figureH * 0.45

            ZStack(alignment: .topLeading) {
                // Floor
                Rectangle().fill(DS.strokeStrong).frame(width: w, height: 1).offset(y: floorY)

                // Table and phone
                Rectangle().fill(DS.stroke).frame(width: tableW, height: 2).offset(x: tableX, y: tableTop)
                Rectangle().fill(DS.stroke).frame(width: 2, height: floorY - tableTop).offset(x: tableX + 4, y: tableTop)
                Rectangle().fill(DS.stroke).frame(width: 2, height: floorY - tableTop).offset(x: tableX + tableW - 6, y: tableTop)
                RoundedRectangle(cornerRadius: 2)
                    .fill(DS.textPrimary)
                    .frame(width: 6, height: 30)
                    .rotationEffect(.degrees(-8), anchor: .bottom)
                    .offset(x: tableX + tableW - 16, y: tableTop - 30)

                // Vertical tape: 105 cm
                TapeLine(ticks: 12, progress: tapes)
                    .stroke(DS.strokeStrong, lineWidth: 1)
                    .frame(width: floorY - tableTop, height: 14)
                    .rotationEffect(.degrees(-90), anchor: .topLeading)
                    .offset(x: tableX - 10, y: floorY)
                MonoTag(text: "105 cm")
                    .offset(x: tableX - 80, y: (tableTop + floorY) / 2 - 12)
                    .opacity(tapes > 0.9 ? 1 : 0)

                // Figure
                BodyGuideShape()
                    .fill(DS.textPrimary.opacity(0.08))
                    .overlay(BodyGuideShape().stroke(DS.textPrimary, lineWidth: 1.5))
                    .frame(width: figureW, height: figureH)
                    .offset(x: figureIn ? figureX - figureW / 2 : w + figureW, y: floorY - figureH + 6)

                // Horizontal tape: 120 cm
                TapeLine(ticks: 24, progress: tapes)
                    .stroke(DS.strokeStrong, lineWidth: 1)
                    .frame(width: figureX - figureW / 2 - (tableX + tableW) - 8, height: 14)
                    .offset(x: tableX + tableW + 4, y: floorY + 10)
                MonoTag(text: "120 cm")
                    .offset(x: (tableX + tableW + figureX - figureW / 2) / 2 - 26, y: floorY + 26)
                    .opacity(tapes > 0.9 ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.3), value: tapes > 0.9)
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active { play() } else { reset() }
        }
    }

    private func play() {
        if reduceMotion { figureIn = true; tapes = 1; return }
        reset()
        withAnimation(.spring(duration: 0.9, bounce: 0.15).delay(0.2)) { figureIn = true }
        withAnimation(.easeOut(duration: 1.0).delay(0.9)) { tapes = 1 }
    }

    private func reset() {
        var t = Transaction(); t.disablesAnimations = true
        withTransaction(t) { figureIn = false; tapes = 0 }
    }
}

// MARK: - 3 · Automatic capture

/// A phone frame with the guide: it turns green, counts 3·2·1, flashes.
struct AutoCaptureIllustration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    private let loop: TimeInterval = 5.2

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let t = reduceMotion ? 2.0 : context.date.timeIntervalSince(start).truncatingRemainder(dividingBy: loop)
            let green = t > 1.1
            let count: Int? = t > 1.6 && t < 4.3 ? max(1, 3 - Int((t - 1.6) / 0.9)) : nil
            let flash = t > 4.3 && t < 4.65
            let done = t >= 4.65

            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.l)
                    .fill(Color(hex: "#2E2824"))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.l).stroke(DS.strokeStrong, lineWidth: 1))

                BodyGuideFigure(look: green ? (count != nil ? .capturing : .aligned) : .searching)
                    .frame(width: 92, height: 200)
                    .offset(y: 10)

                if let count {
                    ZStack {
                        Circle().stroke(DS.success.opacity(0.35), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: CGFloat(4 - count) / 3)
                            .stroke(DS.success, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(count)")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.textPrimary)
                            .contentTransition(.numericText(countsDown: true))
                    }
                    .frame(width: 56, height: 56)
                    .offset(y: 96)
                    .transition(.scale.combined(with: .opacity))
                }

                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DS.bg)
                        .frame(width: 56, height: 56)
                        .background(DS.success, in: Circle())
                        .offset(y: 96)
                        .transition(.scale.combined(with: .opacity))
                }

                RoundedRectangle(cornerRadius: DS.Radius.l)
                    .fill(DS.textPrimary)
                    .opacity(flash ? 0.85 : 0)
            }
            .frame(width: 150, height: 270)
            .animation(.easeInOut(duration: 0.25), value: green)
            .animation(.easeInOut(duration: 0.25), value: count)
            .animation(.easeOut(duration: 0.3), value: flash)
            .animation(.spring(duration: 0.4, bounce: 0.3), value: done)
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active { start = Date() }
        }
    }
}
#endif
