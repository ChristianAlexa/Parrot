import AppKit
import SwiftUI

@MainActor
final class FloatingBarController {
    var panel: FloatingBarPanel?
    private var hostingView: NSHostingView<FloatingBarView>?
    private var prefsObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?

    /// Fixed panel size — large enough for all states.
    /// SwiftUI animates the visible capsule; the window never moves.
    private let panelSize = NSSize(width: 260, height: 36)

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: DefaultsKey.showFloatingBar) as? Bool ?? true
    }

    func setup() {
        guard panel == nil else { return }

        let panel = FloatingBarPanel(contentRect: NSRect(origin: .zero, size: panelSize))

        let view = FloatingBarView(appState: sharedAppState, levelMonitor: sharedAudioLevelMonitor)
        let hosting = NSHostingView(rootView: view)

        let container = NSView(frame: NSRect(origin: .zero, size: panelSize))
        panel.contentView = container

        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        self.hostingView = hosting

        positionPanel(panel)
        if isEnabled {
            panel.orderFront(nil)
        }
        self.panel = panel

        observeStatus()
        observePreference()
        observeScreenChanges()
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return }
                self.positionPanel(panel)
            }
        }
    }

    private func observePreference() {
        prefsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateVisibility()
            }
        }
    }

    private func updateVisibility() {
        guard let panel else { return }
        if isEnabled {
            panel.orderFront(nil)
        } else {
            panel.orderOut(nil)
        }
    }

    private func observeStatus() {
        withObservationTracking {
            _ = sharedAppState.status
        } onChange: {
            Task { @MainActor [weak self] in
                switch sharedAppState.status {
                case .recording:
                    sharedAudioLevelMonitor.reset()
                case .processing:
                    sharedAudioLevelMonitor.freeze()
                default:
                    break
                }
                self?.observeStatus()
            }
        }
    }

    private func positionPanel(_ panel: NSPanel) {
        // Use the primary screen (the one with the menu bar) rather than
        // NSScreen.main, which tracks the focused app's key window and can
        // resolve to a secondary monitor.
        guard let screen = NSScreen.screens.first else { return }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - panelSize.width / 2
        let y = visibleFrame.origin.y + 12
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: panelSize), display: true)
    }
}
