import Combine
import ServiceManagement
import Sparkle
import SwiftUI

/// NSHostingView subclass that enables vibrancy for glass effects.
class GlanceHostingView<Content: View>: NSHostingView<Content> {
    override var allowsVibrancy: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var backgroundPanels: [CGDirectDisplayID: NSPanel] = [:]
    private var menuBarPanels: [CGDirectDisplayID: NSPanel] = [:]
    private var displayRefresh: DispatchWorkItem?
    private var displayRecheck: DispatchWorkItem?
    private var displayLayout: [BarDisplayLayout] = []
    private var statusItem: NSStatusItem?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var hotkeyManager: HotkeyManager?
    private var fullscreenDetector: FullscreenDetector?
    private var fullscreenCancellable: AnyCancellable?
    private var userHidBar = false  // True when user manually hid bar via hotkey

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let error = ConfigManager.shared.initError {
            showFatalConfigError(message: error)
            return
        }

        // Show "What's New" banner if the app version is outdated
        if !VersionChecker.isLatestVersion() {
            VersionChecker.updateVersionFile()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NotificationCenter.default.post(
                    name: Notification.Name("ShowWhatsNewBanner"), object: nil)
            }
        }

        MenuBarPopup.setup()
        setupPanels()
        setupStatusItem()
        setupHotkey()
        setupFullscreenDetection()
        WindowGapManager.shared.start()

        // Show onboarding on first launch
        OnboardingWindowController.shared.showIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(screenParametersDidChange(_:)), name: name, object: nil)
        }
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        // macOS moves windows and changes the primary screen over several
        // notifications. Recreate hosting trees after that transition settles.
        displayRefresh?.cancel()
        displayRecheck?.cancel()
        let refresh = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.setupPanels(rebuild: true)
            SpacesViewModel.shared.refreshAfterDisplayChange()
            self.fullscreenDetector?.check()
        }
        displayRefresh = refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: refresh)
        let recheck = DispatchWorkItem { [weak self] in
            self?.setupPanels()
            SpacesViewModel.shared.refreshAfterDisplayChange()
        }
        displayRecheck = recheck
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: recheck)
    }


    // MARK: - File & URL Open

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "glance" {
                PresetShareManager.applyPresetURL(url)
            } else if url.pathExtension == "glance" {
                PresetShareManager.applyPresetFile(at: url)
            }
        }
    }

    // MARK: - Status Item (Tray Icon)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Glance")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Glance"
        }

        let menu = NSMenu()

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Check for Updates
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Glance", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if isLaunchAtLoginEnabled {
                try service.unregister()
                sender.state = .off
            } else {
                try service.register()
                sender.state = .on
            }
        } catch {
            AppLogger.shared.error("Failed to toggle launch at login: \(error.localizedDescription)", category: .app)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Panels

    /// Configures and displays the background and menu bar panels.
    private func setupPanels(rebuild: Bool = false) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let layout = screens.map { BarDisplayLayout(id: $0.displayID, frame: $0.frame) }
        if rebuild || layout != displayLayout {
            MenuBarPopup.reset()
            // Release old SwiftUI trees and their widget lifecycle state before
            // creating replacements. A migrated NSPanel can retain stale state.
            for panel in Array(menuBarPanels.values) + Array(backgroundPanels.values) {
                panel.orderOut(nil)
                panel.contentView = nil
                panel.close()
            }
            menuBarPanels.removeAll()
            backgroundPanels.removeAll()
            displayLayout = layout
        }
        let connected = Set(screens.map(\.displayID))
        for id in Array(menuBarPanels.keys) where !connected.contains(id) {
            menuBarPanels.removeValue(forKey: id)?.close()
            backgroundPanels.removeValue(forKey: id)?.close()
        }
        let barHeight = ConfigManager.shared.config.experimental.foreground.resolveHeight()
        for screen in screens {
            let id = screen.displayID
            let frame = screen.frame
            let barFrame = NSRect(x: frame.minX, y: frame.maxY - barHeight,
                                  width: frame.width, height: barHeight)
            var background = backgroundPanels[id]
            var bar = menuBarPanels[id]
            setupPanel(&background, frame: frame,
                       level: Int(CGWindowLevelForKey(.desktopWindow)),
                       hostingRootView: AnyView(BackgroundView().environment(\.barDisplayID, id)))
            setupPanel(&bar, frame: barFrame,
                       level: Int(CGWindowLevelForKey(.backstopMenu)),
                       hostingRootView: AnyView(MenuBarView().environment(\.barDisplayID, id)))
            backgroundPanels[id] = background
            menuBarPanels[id] = bar
        }
        updatePanelVisibility(animated: false)
    }

    /// Sets up an NSPanel with the provided parameters.
    private func setupPanel(
        _ panel: inout NSPanel?, frame: CGRect, level: Int,
        hostingRootView: AnyView
    ) {
        if let existingPanel = panel {
            existingPanel.setFrame(frame, display: true)
            return
        }

        let newPanel = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false)
        newPanel.isReleasedWhenClosed = false
        newPanel.level = NSWindow.Level(rawValue: level)
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.collectionBehavior = [.canJoinAllSpaces]
        newPanel.titlebarAppearsTransparent = true

        let hostingView = GlanceHostingView(rootView: hostingRootView)
        newPanel.contentView = hostingView

        newPanel.orderFront(nil)
        panel = newPanel
    }

    // MARK: - Hotkey (Show/Hide Bar)

    private func setupHotkey() {
        let config = ConfigManager.shared.config.rootToml
        let hotkeyString = config.hotkey ?? "ctrl+option+b"
        guard hotkeyString != "false" else { return }

        guard let parsed = HotkeyManager.parse(hotkeyString) else { return }

        let manager = HotkeyManager()
        manager.onToggle = { [weak self] in
            self?.toggleBarVisibility()
        }
        manager.register(modifiers: parsed.modifiers, keyCode: parsed.keyCode)
        hotkeyManager = manager
    }

    private func toggleBarVisibility() {
        userHidBar.toggle()
        updatePanelVisibility(animated: true)
    }

    // MARK: - Fullscreen Auto-Hide

    private func setupFullscreenDetection() {
        guard ConfigManager.shared.config.experimental.foreground.autoHide else { return }
        let detector = FullscreenDetector()
        fullscreenDetector = detector
        fullscreenCancellable = detector.$fullscreenDisplayIDs
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updatePanelVisibility(animated: true) }
    }

    private func updatePanelVisibility(animated: Bool) {
        let hidden = fullscreenDetector?.fullscreenDisplayIDs ?? []
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? 0.2 : 0
            for (id, panel) in menuBarPanels {
                let alpha: CGFloat = userHidBar || hidden.contains(id) ? 0 : 1
                panel.animator().alphaValue = alpha
                backgroundPanels[id]?.animator().alphaValue = alpha
            }
        }
    }

    private func showFatalConfigError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Configuration Error"
        alert.informativeText = "\(message)\n\nPlease double check ~/.glance-config.toml and try again."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")

        alert.runModal()
        NSApplication.shared.terminate(nil)
    }
}
