import SwiftUI

struct StatusIndicatorView: View {
    let appState: AppState

    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode: Int = 61
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers: Int = 0
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: appState.statusIcon)
                .font(.system(size: 28))
                .foregroundStyle(statusColor)
                .symbolEffect(.pulse, isActive: appState.status == .recording)
                .contentTransition(.symbolEffect(.replace))
                .frame(height: 34)

            Text(appState.statusDescription)
                .font(.system(.headline, weight: .medium))
                .foregroundStyle(.primary)

            subtitleText

            if appState.status == .idle {
                Button {
                    if appState.isModelsLoaded {
                        NotificationCenter.default.post(name: .unloadModelsRequested, object: nil)
                    } else {
                        NotificationCenter.default.post(name: .loadModelsRequested, object: nil)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: appState.isModelsLoaded ? "arrow.down.to.line" : "arrow.up.to.line")
                            .font(.system(size: 10))
                        Text(appState.isModelsLoaded ? "Unload Models" : "Load Models")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(statusBackground)
        .animation(.easeInOut(duration: 0.3), value: appState.status)
        .onChange(of: appState.status) { _, newStatus in
            if newStatus == .recording {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    isPulsing = false
                }
            }
        }
    }

    @ViewBuilder
    private var subtitleText: some View {
        switch appState.status {
        case .idle:
            if appState.isModelsLoaded {
                Text("Hold \(KeyCodeNames.displayName(for: UInt16(hotkeyKeyCode), modifiers: UInt32(hotkeyModifiers))) to record")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if !appState.modelLoadingProgress.isEmpty {
                Text(appState.modelLoadingProgress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .error(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        default:
            EmptyView()
        }
    }

    private var statusBackground: some View {
        RoundedRectangle(cornerRadius: MenuBarStyle.statusCornerRadius)
            .fill(statusBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: MenuBarStyle.statusCornerRadius)
                    .strokeBorder(
                        appState.status == .recording
                            ? Color.red.opacity(isPulsing ? 0.3 : 0.1)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )
    }

    private var statusBackgroundColor: Color {
        switch appState.status {
        case .idle:
            return appState.isModelsLoaded
                ? Color.primary.opacity(0.04)
                : Color.orange.opacity(0.08)
        case .recording:
            return Color.red.opacity(isPulsing ? 0.14 : 0.08)
        case .processing:
            return Color.blue.opacity(0.08)
        case .error:
            return Color.red.opacity(0.08)
        }
    }

    private var statusColor: Color {
        switch appState.status {
        case .idle:
            return appState.isModelsLoaded ? .secondary : .orange
        case .recording:
            return .red
        case .processing:
            return .blue
        case .error:
            return .red
        }
    }
}
