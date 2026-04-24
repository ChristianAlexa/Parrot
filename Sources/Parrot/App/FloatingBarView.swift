import SwiftUI

struct FloatingBarView: View {
    let appState: AppState
    let levelMonitor: AudioLevelMonitor

    @State private var showErrorFace = false

    private var isRecording: Bool { appState.status == .recording }
    private var isProcessing: Bool { appState.status == .processing }
    private var isError: Bool { if case .error = appState.status { return true } else { return false } }
    private var isActive: Bool { isRecording || isProcessing }
    private var isIdle: Bool { !isActive && !showErrorFace }

    private var contentWidth: CGFloat { isIdle ? 44 : 260 }
    private var contentHeight: CGFloat { isIdle ? 16 : 36 }

    var body: some View {
        ZStack {
            idleContent
                .opacity(isActive || showErrorFace ? 0 : 1)
            if showErrorFace {
                Text("x__x")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            waveformContent(levels: levelMonitor.levels, animated: true)
                .opacity(isRecording ? 1 : 0)
            if isProcessing, let frozen = levelMonitor.frozenLevels {
                HStack(spacing: 8) {
                    waveformContent(levels: frozen, animated: false)
                    AnimatedDots()
                }
            }
        }
        .frame(width: contentWidth, height: contentHeight)
        .clipped()
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(
                    color: .black.opacity(isIdle ? 0.15 : 0.4),
                    radius: isIdle ? 4 : 12,
                    y: isIdle ? 1 : 4
                )
        )
        .clipShape(Capsule())
        .frame(width: 260, height: 36)
        .animation(.easeInOut(duration: 0.4), value: appState.status)
        .animation(.easeInOut(duration: 0.2), value: showErrorFace)
        .onChange(of: isError) { _, isNowError in
            if isNowError {
                showErrorFace = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showErrorFace = false
                }
            }
        }
    }

    // MARK: - Idle

    private var idleContent: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 3, height: 3)
            }
        }
    }

    // MARK: - Waveform

    private func waveformContent(levels: [Float], animated: Bool) -> some View {
        HStack(spacing: 2.5) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                let boosted = sqrt(CGFloat(level))
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white)
                    .frame(width: 4, height: max(3, boosted * 28))
            }
        }
        .frame(height: 30)
        .animation(animated ? .spring(duration: 0.08) : nil, value: levels)
    }
}

// MARK: - Animated Dots

private struct AnimatedDots: View {
    @State private var active = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .opacity(active ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: active
                    )
            }
        }
        .onAppear { active = true }
    }
}
