//
//  CameraView.swift
//  guaperrimo.ai
//

#if os(iOS)
import AVFoundation
import SwiftUI

// MARK: - Shake gesture detector

#if DEBUG
struct ShakeDetector: UIViewRepresentable {
    let onShake: () -> Void

    func makeUIView(context: Context) -> ShakeDetectorUIView {
        let view = ShakeDetectorUIView()
        view.onShake = onShake
        return view
    }

    func updateUIView(_ uiView: ShakeDetectorUIView, context: Context) {
        uiView.onShake = onShake
    }

    final class ShakeDetectorUIView: UIView {
        var onShake: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            becomeFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake {
                onShake?()
            }
        }
    }
}
#endif

// MARK: - Main camera view

struct CameraView: View {
    @State private var shoppingStore = ShoppingListStore.shared
    @State private var showShoppingList = false
    @State private var cameraManager = CameraManager()
    @State private var countdownRemaining: Int = 0
    @State private var countdownActive = false
    @State private var countdownTimer: Timer?
    @State private var countdownProgress: CGFloat = 0.0
    @State private var showFlash = false
    @State private var showOnboarding: Bool
    @State private var showHelp = false
    @State private var debugTimerActive = false
    @State private var debugTimerRemaining: Int = 0
    @State private var debugTimer: Timer?
    #if DEBUG
    @State private var showDebugPanel = true
    #endif

    init() {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: OnboardingView.seenKey)
        _showOnboarding = State(initialValue: !hasSeenOnboarding)
    }

    private var posState: PositioningState {
        cameraManager.bodyPoseDetector.positioningState
    }

    var body: some View {
        if showOnboarding {
            OnboardingView {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showOnboarding = false
                }
            }
        } else {
            cameraContent
        }
    }

    private var cameraContent: some View {
        ZStack {
            // Layer 1: Camera preview
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()

            // Layer 2: framing guide and the large instruction
            CameraGuideLayer(
                state: posState,
                countdownActive: countdownActive,
                setupHint: String(localized: "camera_hint")
            )
            .ignoresSafeArea()

            // Layer 3: Controls
            VStack(spacing: 0) {
                // Help: reopens the placement page of the onboarding
                HStack {
                    Spacer()
                    IconButton(systemName: "questionmark", accessibilityLabel: String(localized: "camera_help")) {
                        showHelp = true
                    }
                    .padding(.trailing, DS.Space.m)
                    .padding(.top, 52)
                }

                Spacer()

                // Capture controls
                HStack(alignment: .center, spacing: 40) {
                    #if DEBUG
                    // 5s timer button (debug only: captures after 5 s ignoring pose detection)
                    Button {
                        startDebugTimer()
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .stroke(.white.opacity(0.6), lineWidth: 2)
                                    .frame(width: 50, height: 50)
                                if debugTimerActive {
                                    Text("\(debugTimerRemaining)")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.yellow)
                                } else {
                                    Image(systemName: "timer")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text("5s")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .disabled(debugTimerActive || countdownActive)
                    #else
                    Color.clear
                        .frame(width: 50, height: 50)
                    #endif

                    // Main capture / countdown
                    ZStack {
                        if countdownActive {
                            Circle()
                                .trim(from: 0, to: countdownProgress)
                                .stroke(DS.success, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 110, height: 110)

                            Text("\(countdownRemaining)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .contentTransition(.numericText(countsDown: true))
                                .foregroundStyle(DS.textPrimary)
                        } else {
                            Button {
                                cameraManager.capturePhoto()
                                triggerFlash()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(DS.textPrimary)
                                        .frame(width: 72, height: 72)
                                    Circle()
                                        .stroke(DS.textPrimary, lineWidth: 4)
                                        .frame(width: 82, height: 82)
                                }
                            }
                            .disabled(debugTimerActive)
                        }
                    }

                    // Spacer to balance layout
                    Color.clear
                        .frame(width: 50, height: 50)
                }
                .padding(.bottom, 40)
            }

            // Layer 3b: shortcut to the saved shopping list
            if shoppingStore.hasList {
                VStack {
                    HStack {
                        Button {
                            showShoppingList = true
                        } label: {
                            Image(systemName: "bag.fill")
                                .font(.headline)
                                .foregroundStyle(DS.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(DS.bg.opacity(0.6), in: Circle())
                                .overlay(Circle().stroke(DS.strokeStrong, lineWidth: 1))
                        }
                        .accessibilityLabel(String(localized: "shopping_title"))
                        .padding(.leading, 16)
                        .padding(.top, 52)
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Layer 4: Flash overlay
            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Permission denied overlay
            if cameraManager.cameraPermission == .denied ||
                cameraManager.cameraPermission == .restricted {
                CameraPermissionView()
            }

            #if DEBUG
            // Debug panel overlay (top-right)
            if showDebugPanel {
                debugPanelOverlay
            }

            // Shake detector (invisible, just listens for shake)
            ShakeDetector {
                showDebugPanel.toggle()
            }
            .frame(width: 0, height: 0)
            #endif
        }
        .statusBarHidden()
        .sheet(isPresented: $showShoppingList) {
            ShoppingListView()
        }
        .fullScreenCover(isPresented: $showHelp) {
            OnboardingView(startPage: 1) {
                showHelp = false
            }
        }
        .onChange(of: posState) { oldState, newState in
            handleStateChange(from: oldState, to: newState)
        }
        .onChange(of: cameraManager.bodyPoseDetector.averageJointDisplacement) { _, newDisplacement in
            if countdownActive && newDisplacement > PositioningConfig.movementCancelThresholdPx {
                cancelCountdown()
            }
        }
        .fullScreenCover(isPresented: $cameraManager.isPhotoTaken) {
            if let image = cameraManager.capturedImage {
                PhotoPreviewView(
                    image: image,
                    onRetake: {
                        cameraManager.retakePhoto()
                    }
                )
            }
        }
        .onAppear {
            cameraManager.checkPermission()
        }
        .onDisappear {
            cancelCountdown()
            cancelDebugTimer()
            cameraManager.stopSession()
        }
    }

    // MARK: - State transitions

    private func handleStateChange(from oldState: PositioningState, to newState: PositioningState) {
        switch newState {
        case .stillConfirmed:
            if !countdownActive {
                startCountdown()
            }
        case .aligned:
            // Still aligned but moving -- don't cancel yet
            break
        default:
            if countdownActive {
                cancelCountdown()
            }
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        let total = PositioningConfig.countdownSeconds
        countdownRemaining = total
        countdownProgress = 0.0
        countdownActive = true

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard countdownActive else { return }
                countdownRemaining -= 1

                withAnimation(.linear(duration: 1.0)) {
                    countdownProgress = CGFloat(total - countdownRemaining) / CGFloat(total)
                }

                if countdownRemaining <= 0 {
                    cancelCountdown()
                    cameraManager.capturePhoto()
                    triggerFlash()
                }
            }
        }

        // Animate the first segment
        withAnimation(.linear(duration: 1.0)) {
            countdownProgress = 1.0 / CGFloat(total)
        }
    }

    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownActive = false
        countdownRemaining = 0
        countdownProgress = 0.0
    }

    // MARK: - Debug 5s timer (ignores pose detection)

    private func startDebugTimer() {
        guard !debugTimerActive else { return }
        debugTimerRemaining = 5
        debugTimerActive = true

        debugTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard debugTimerActive else { return }
                debugTimerRemaining -= 1
                if debugTimerRemaining <= 0 {
                    cancelDebugTimer()
                    cameraManager.debugOverlayEnabled = true
                    cameraManager.debugScreenSize = UIScreen.main.bounds.size
                    cameraManager.capturePhoto()
                    triggerFlash()
                }
            }
        }
    }

    private func cancelDebugTimer() {
        debugTimer?.invalidate()
        debugTimer = nil
        debugTimerActive = false
        debugTimerRemaining = 0
    }

    private func triggerFlash() {
        showFlash = true
        withAnimation(.easeOut(duration: 0.15)) {
            showFlash = false
        }
    }

    // MARK: - Debug panel

    #if DEBUG
    private var debugPanelOverlay: some View {
        let info = cameraManager.bodyPoseDetector.debugInfo
        let displacement = cameraManager.bodyPoseDetector.averageJointDisplacement

        return VStack(alignment: .leading, spacing: 4) {
            Text("CONFIRMED: \(String(describing: posState))")
            Text("RAW: \(String(describing: info.rawState))")
            Text(String(format: "Displacement: %.1f px", displacement))
            Text(String(format: "Shoulder W: %.0f px", info.shoulderWidthPx))
            Text(String(format: "Center X: %.3f", info.centerOffsetX))
            Text(String(format: "Neck Y: %.3f", info.neckY))
            Text(String(format: "Stillness: %.0f%%", info.stillnessProgress * 100))

            Divider().background(.white.opacity(0.3))

            ForEach(Array(info.joints.enumerated()), id: \.offset) { _, joint in
                HStack(spacing: 4) {
                    Circle()
                        .fill(joint.confidence > PositioningConfig.jointConfidenceMin ? DS.success : Color.red)
                        .frame(width: 6, height: 6)
                    Text(String(format: "%@ %.2f", joint.name, joint.confidence))
                }
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 80)
        .padding(.trailing, 8)
        .allowsHitTesting(false)
    }
    #endif
}
#endif
