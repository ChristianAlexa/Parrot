import SwiftUI
import os

extension Notification.Name {
    static let inferenceSettingsDidChange = Notification.Name("inferenceSettingsDidChange")
    static let testRecordingStarted = Notification.Name("testRecordingStarted")
    static let testRecordingStopped = Notification.Name("testRecordingStopped")
    static let transcriptionCompleted = Notification.Name("transcriptionCompleted")
    static let transcriptionFailed = Notification.Name("transcriptionFailed")
    static let unloadModelsRequested = Notification.Name("unloadModelsRequested")
    static let loadModelsRequested = Notification.Name("loadModelsRequested")
}

@MainActor
let sharedAppState = AppState()

@MainActor
let sharedAudioDeviceManager = AudioDeviceManager()

@MainActor
let sharedModelDownloader = ModelDownloader()

@main
struct ParrotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
        } label: {
            Image(systemName: sharedAppState.statusIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
struct MenuBarContentView: View {
    @State private var selectedTab: SidebarTab = .record

    var body: some View {
        Group {
            if sharedAppState.currentSetupStep != .complete {
                SetupFlowView()
            } else {
                normalContentView
            }
        }
        .background(OpaqueWindowBackground())
        .frame(width: MenuBarStyle.settingsWidth, height: 480)
    }

    private var normalContentView: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    SidebarTabButton(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }

                Spacer()

                // Quit
                Button { _exit(0) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "power")
                            .font(.system(size: 16))
                            .foregroundStyle(.red)
                        Text("Quit")
                            .font(.caption2)
                    }
                    .frame(width: MenuBarStyle.sidebarWidth, height: 44)
                    .contentShape(Rectangle())
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit Parrot")
            }
            .padding(.vertical, 8)
            .frame(width: MenuBarStyle.sidebarWidth)
            .background(Color.primary.opacity(0.03))

            Divider()

            // Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Parrot")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(versionString)
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

                Divider()
                    .padding(.horizontal, 12)

                // Tab content
                ScrollView {
                    tabContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .record:
            RecordTabView()
        case .output:
            OutputStyleView()
        case .settings:
            SettingsTabView()
        case .stats:
            StatsTabView()
        case .models:
            ModelsTabView()
        case .about:
            AboutTabView()
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        return "v\(version)"
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.parrot", category: "App")
    private let pipeline = TranscriptionPipeline()
    private let floatingBarController = FloatingBarController()
    private let textInjector = TextInjector()
    private lazy var hotkeyManager: HotkeyManager = {
        let saved = UserDefaults.standard.integer(forKey: DefaultsKey.hotkeyKeyCode)
        let savedMods = UserDefaults.standard.integer(forKey: DefaultsKey.hotkeyModifiers)
        return HotkeyManager(keyCode: UInt16(saved > 0 ? saved : 61), modifiers: UInt32(savedMods))
    }()
    private let modelManager = ModelManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Parrot launched")
        ActivityLog.shared.log(.info, category: "App", message: "Parrot launched")

        modelManager.ensureModelsDirectoryExists()
        sharedModelsStore.refresh()
        sharedAppState.refreshSetupState()

        if sharedAppState.currentSetupStep == .complete {
            setupHotkey()
            pipeline.loadModels()
            floatingBarController.setup()
        } else {
            observeSetupCompletion()
        }
        observeSettingsChanges()
        observeTranscriptionCompleted()
    }

    private func observeTranscriptionCompleted() {
        NotificationCenter.default.addObserver(
            forName: .transcriptionCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self else { return }
                let isTest = notification.userInfo?["isTest"] as? Bool ?? false
                guard !isTest else { return }
                guard let text = notification.userInfo?["text"] as? String else { return }
                self.textInjector.inject(text)
            }
        }
    }

    private func observeSetupCompletion() {
        withObservationTracking {
            _ = sharedAppState.currentSetupStep
        } onChange: {
            Task { @MainActor [self] in
                if sharedAppState.currentSetupStep == .complete {
                    self.setupHotkey()
                    self.pipeline.loadModels()
                    self.floatingBarController.setup()
                } else {
                    self.observeSetupCompletion()
                }
            }
        }
    }

    private func setupHotkey() {
        hotkeyManager.onRecordingStarted = { [weak self] in
            Task { @MainActor in
                self?.pipeline.startRecording()
            }
        }
        hotkeyManager.onRecordingStopped = { [weak self] in
            Task { @MainActor in
                self?.pipeline.stopRecordingAndProcess()
            }
        }


        NotificationCenter.default.addObserver(
            forName: .hotkeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let keyCode = notification.userInfo?["keyCode"] as? UInt16 else { return }
                let modifiers = notification.userInfo?["modifiers"] as? UInt32 ?? 0
                self?.hotkeyManager.updateKeyCode(keyCode, modifiers: modifiers)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .hotkeyStartCapture,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hotkeyManager.startCapture()
            }
        }

        if !hotkeyManager.start() {
            logger.warning("Hotkey setup failed — accessibility permission may be needed")
            ActivityLog.shared.log(.warning, category: "App", message: "Hotkey setup failed — accessibility permission may be needed")
            sharedAppState.status = .error("Accessibility permission required — grant in System Settings → Privacy & Security → Accessibility, then relaunch Parrot")
        }
    }

    private func observeSettingsChanges() {
        NotificationCenter.default.addObserver(
            forName: .inferenceSettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pipeline.loadModels()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .unloadModelsRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pipeline.unloadModels()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .loadModelsRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.pipeline.loadModels()
            }
        }
    }
}
