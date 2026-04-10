import SwiftUI

struct ShortcutRecorderButton: View {
    @AppStorage(DefaultsKey.hotkeyKeyCode) private var hotkeyKeyCode: Int = 61
    @AppStorage(DefaultsKey.hotkeyModifiers) private var hotkeyModifiers: Int = 0
    @State private var isRecording = false
    @State private var displayName: String = ""

    var body: some View {
        Button {
            if isRecording {
                isRecording = false
            } else {
                isRecording = true
                NotificationCenter.default.post(name: .hotkeyStartCapture, object: nil)
            }
        } label: {
            Text(isRecording ? "Press keys…" : (displayName.isEmpty ? "Record Shortcut" : displayName))
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .font(.system(size: 12))
                .foregroundStyle(isRecording ? Color.accentColor : .secondary)
        }
        .buttonStyle(RecorderButtonStyle(isRecording: isRecording))
        .onAppear {
            displayName = KeyCodeNames.displayName(for: UInt16(hotkeyKeyCode), modifiers: UInt32(hotkeyModifiers))
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyCaptured)) { notification in
            guard isRecording else { return }
            guard let keyCode = notification.userInfo?["keyCode"] as? UInt16 else { return }
            let modifiers = notification.userInfo?["modifiers"] as? UInt32 ?? 0

            hotkeyKeyCode = Int(keyCode)
            hotkeyModifiers = Int(modifiers)
            displayName = KeyCodeNames.displayName(for: keyCode, modifiers: modifiers)
            isRecording = false

            NotificationCenter.default.post(
                name: .hotkeyDidChange,
                object: nil,
                userInfo: ["keyCode": keyCode, "modifiers": modifiers]
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .hotkeyCancelled)) { _ in
            guard isRecording else { return }
            isRecording = false
        }
    }
}

// MARK: - Button Style

private struct RecorderButtonStyle: ButtonStyle {
    let isRecording: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording
                          ? Color.accentColor.opacity(0.1)
                          : Color(nsColor: .quaternaryLabelColor).opacity(configuration.isPressed ? 1.0 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.accentColor : Color(nsColor: .separatorColor),
                            lineWidth: isRecording ? 1.5 : 0.5)
            )
    }
}
