import SwiftUI
import AppKit

/// NSView-based background that disables the window's translucency,
/// making the MenuBarExtra panel fully opaque.
struct OpaqueWindowBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor

            // Remove any visual effect (vibrancy) views
            if let contentView = window.contentView {
                for subview in contentView.subviews where subview is NSVisualEffectView {
                    (subview as? NSVisualEffectView)?.state = .inactive
                    (subview as? NSVisualEffectView)?.material = .windowBackground
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum MenuBarStyle {
    static let panelWidth: CGFloat = 300
    static let settingsWidth: CGFloat = 650
    static let sidebarWidth: CGFloat = 80
    static let statusCornerRadius: CGFloat = 10
    static let rowCornerRadius: CGFloat = 6
}

enum SidebarTab: String, CaseIterable {
    case record
    case output
    case settings
    case models
    case about

    var icon: String {
        switch self {
        case .record: return "waveform"
        case .output: return "slider.horizontal.3"
        case .settings: return "gearshape"
        case .models: return "square.stack.3d.down.right"
        case .about: return "info.circle"
        }
    }

    var label: String {
        switch self {
        case .record: return "Record"
        case .output: return "Tone"
        case .settings: return "System"
        case .models: return "Models"
        case .about: return "About"
        }
    }
}

struct SidebarTabButton: View {
    let tab: SidebarTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                Text(tab.label)
                    .font(.caption2)
            }
            .frame(width: MenuBarStyle.sidebarWidth, height: 52)
            .contentShape(Rectangle())
            .foregroundStyle(isSelected ? .primary : .secondary)
            .background(
                RoundedRectangle(cornerRadius: MenuBarStyle.rowCornerRadius)
                    .fill(Color.primary.opacity(isSelected ? 0.08 : (isHovered ? 0.04 : 0)))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct MenuRowButton: View {
    let title: String
    let icon: String
    let shortcutKey: KeyEquivalent
    let shortcutModifiers: EventModifiers
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text(title)
                    .font(.body)

                Spacer()

                Text(shortcutHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: MenuBarStyle.rowCornerRadius)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .keyboardShortcut(shortcutKey, modifiers: shortcutModifiers)
    }

    private var shortcutHint: String {
        var parts: [String] = []
        if shortcutModifiers.contains(.command) { parts.append("⌘") }
        if shortcutModifiers.contains(.shift) { parts.append("⇧") }
        if shortcutModifiers.contains(.option) { parts.append("⌥") }
        if shortcutModifiers.contains(.control) { parts.append("⌃") }
        parts.append(String(shortcutKey.character))
        return parts.joined()
    }
}
