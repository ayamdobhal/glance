import Cocoa

/// Monitors all application windows via the Accessibility API and adjusts any window
/// whose top edge overlaps the Glance status bar, pushing it down with a small gap.
///
/// Requires Accessibility permission — prompts the user on first launch if not granted.
final class WindowGapManager {
    static let shared = WindowGapManager()

    private var observers: [pid_t: AXObserver] = [:]
    private var isRunning = false
    private var accessibilityPollTimer: Timer?
    private let myPID = ProcessInfo.processInfo.processIdentifier
    private let logger = AppLogger.shared

    /// Minimum Y (in AX top-left coordinates) where a window's top edge may sit.
    private var threshold: CGFloat {
        ConfigManager.shared.config.experimental.foreground.resolveHeight() + 6
    }

    func start() {
        guard !isRunning else { return }
        guard AXIsProcessTrusted() else {
            promptForAccessibility()
            return
        }

        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
        isRunning = true
        logger.info("Starting window gap monitoring", category: .windowGap)

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            registerObserver(for: app.processIdentifier)
        }

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(appLaunched(_:)),
                           name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.addObserver(self, selector: #selector(appTerminated(_:)),
                           name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        // Delayed sweep: on reboot, macOS state restoration may reposition windows
        // after they are created. A second pass catches windows that were moved back
        // to their saved (overlapping) position after the initial scan.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.adjustAllRunningApps()
        }
    }

    // MARK: - App Lifecycle

    @objc private func appLaunched(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.activationPolicy == .regular else { return }
        registerObserver(for: app.processIdentifier)
    }

    @objc private func appTerminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        unregisterObserver(for: app.processIdentifier)
    }

    // MARK: - AX Observers

    private func registerObserver(for pid: pid_t) {
        guard pid != myPID, observers[pid] == nil else { return }

        var obs: AXObserver?
        let observerStatus = AXObserverCreate(pid, windowGapAXCallback, &obs)
        guard observerStatus == .success, let observer = obs else {
            logger.warning("Failed to create AX observer for pid \(pid): \(observerStatus.rawValue)", category: .windowGap)
            return
        }

        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let notifications: [String] = [
            kAXWindowResizedNotification,
            kAXWindowMovedNotification,
            kAXWindowCreatedNotification,
            kAXFocusedWindowChangedNotification,
        ]
        for notif in notifications {
            let status = AXObserverAddNotification(observer, appElement, notif as CFString, refcon)
            if status != .success && status != .notificationAlreadyRegistered {
                logger.warning(
                    "Failed to register AX notification \(notif) for pid \(pid): \(status.rawValue)",
                    category: .windowGap
                )
            }
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        observers[pid] = observer

        // Scan existing windows that may already overlap the bar.
        // On reboot, windows are restored to saved positions before observers fire.
        adjustAllWindows(of: appElement)
    }

    private func unregisterObserver(for pid: pid_t) {
        guard let obs = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
    }

    // MARK: - Initial Window Scan

    /// Iterates all windows of a given application element and pushes down any that overlap the bar.
    private func adjustAllWindows(of appElement: AXUIElement) {
        var windowsRef: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return }
        for window in windows {
            adjustIfOverlapping(window)
        }
    }

    /// Sweeps all running apps and adjusts overlapping windows.
    /// Used as a delayed pass on boot to catch state-restored positions.
    private func adjustAllRunningApps() {
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard app.processIdentifier != myPID else { continue }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            adjustAllWindows(of: appElement)
        }
    }

    // MARK: - Event Handling

    fileprivate func handleWindowEvent(_ element: AXUIElement, notification: String) {
        if notification == kAXWindowCreatedNotification {
            // Newly created windows may not have their final frame yet.
            // ARC retains the AXUIElement when captured by the closure.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.resolveAndAdjust(element)
            }
        } else {
            resolveAndAdjust(element)
        }
    }

    private func resolveAndAdjust(_ element: AXUIElement) {
        guard let role = stringAttribute(kAXRoleAttribute, of: element) else { return }

        if role == (kAXWindowRole as String) {
            adjustIfOverlapping(element)
        } else {
            // Element might be an application — try its focused window.
            if let window = elementAttribute(kAXFocusedWindowAttribute, of: element) {
                adjustIfOverlapping(window)
            }
        }
    }

    /// Checks whether the given window overlaps the Glance bar area and, if so,
    /// pushes it down and shrinks its height to maintain a gap.
    private func adjustIfOverlapping(_ window: AXUIElement) {
        // Skip full-screen windows (green-button full screen, not zoom).
        if boolAttribute("AXFullScreen", of: window) == true { return }

        // --- Position (AX coordinate system: origin at top-left of main display) ---
        guard let pos = pointAttribute(kAXPositionAttribute, of: window) else { return }

        guard let size = sizeAttribute(kAXSizeAttribute, of: window) else { return }
        let screens = NSScreen.screens
        guard let primaryTop = screens.first?.frame.maxY else { return }
        let frames = screens.map { DisplayGeometry.accessibilityFrame($0.frame, primaryTop: primaryTop) }
        guard let index = DisplayGeometry.containingDisplay(
            for: CGRect(origin: pos, size: size), displays: frames) else { return }
        let t = frames[index].minY + threshold
        guard pos.y < t else { return }

        let delta = t - pos.y
        var newPos  = CGPoint(x: pos.x, y: t)
        var newSize = CGSize(width: size.width, height: max(size.height - delta, 100))

        if let pv = AXValueCreate(.cgPoint, &newPos) {
            let status = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv)
            if status != .success {
                logger.warning("Failed to set window position: \(status.rawValue)", category: .windowGap)
            }
        }
        if let sv = AXValueCreate(.cgSize, &newSize) {
            let status = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sv)
            if status != .success {
                logger.warning("Failed to set window size: \(status.rawValue)", category: .windowGap)
            }
        }
    }

    // MARK: - Accessibility Permission

    private func promptForAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        logger.info("Requested Accessibility permission for window gap manager", category: .windowGap)

        // Poll until the user grants permission.
        guard accessibilityPollTimer == nil else { return }
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.accessibilityPollTimer = nil
                self?.logger.info("Accessibility permission granted", category: .windowGap)
                self?.start()
            }
        }
        accessibilityPollTimer?.tolerance = 0.5
    }

    private func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func boolAttribute(_ attribute: String, of element: AXUIElement) -> Bool? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? Bool
    }

    private func elementAttribute(_ attribute: String, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func pointAttribute(_ attribute: String, of element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(axValue, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(_ attribute: String, of element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == .cgSize else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(axValue, .cgSize, &size) ? size : nil
    }
}

// MARK: - C-convention AXObserver callback

private func windowGapAXCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let manager = Unmanaged<WindowGapManager>.fromOpaque(refcon).takeUnretainedValue()
    manager.handleWindowEvent(element, notification: notification as String)
}
