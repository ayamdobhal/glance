import SwiftUI

private var panel: NSPanel?

class HidingPanel: NSPanel, NSWindowDelegate {
    var hideTimer: Timer?

    override var canBecomeKey: Bool {
        return true
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing bufferingType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect, styleMask: style, backing: bufferingType,
            defer: flag)
        self.delegate = self
    }

    func windowDidResignKey(_ notification: Notification) {
        NotificationCenter.default.post(name: .willHideWindow, object: nil)
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(
                Constants.menuBarPopupAnimationDurationInMilliseconds) / 1000.0,
            repeats: false
        ) { [weak self] _ in
            self?.orderOut(nil)
        }
    }
}

/// NSHostingView subclass that enables vibrancy for glass effects.
class VibrancyHostingView<Content: View>: NSHostingView<Content> {
    override var allowsVibrancy: Bool { true }
}

class MenuBarPopup {
    static var lastContentIdentifier: String? = nil
    private static var displayID: CGDirectDisplayID?
    private static var generation = 0

    static func reset() {
        generation += 1
        (panel as? HidingPanel)?.hideTimer?.invalidate()
        panel?.close()
        panel = nil
        lastContentIdentifier = nil
        displayID = nil
    }

    /// Release a popup whose owning widget has been removed or replaced.
    static func dismiss(id: String, onDisplay: CGDirectDisplayID? = nil) {
        if let onDisplay, onDisplay != displayID { return }
        guard lastContentIdentifier == id else { return }
        generation += 1
        lastContentIdentifier = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
    }

    static func show<Content: View>(
        rect: CGRect, id: String, onDisplay: CGDirectDisplayID? = nil, @ViewBuilder content: @escaping () -> Content
    ) {
        // SwiftUI's .global rect is local to its hosting window. Keep it local
        // and move the popup panel onto the originating bar's actual screen.
        let eventScreen = NSApp.currentEvent?.window?.screen
        guard let screen = onDisplay.flatMap({ id in NSScreen.screens.first { $0.displayID == id } })
            ?? eventScreen
            ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.screens.first else { return }
        if panel == nil { setup() }
        guard let panel else { return }
        let sameDisplay = displayID == screen.displayID
        if !sameDisplay {
            panel.orderOut(nil)
            panel.contentView = nil
            lastContentIdentifier = nil
        }
        displayID = screen.displayID
        let height = ConfigManager.shared.config.experimental.foreground.resolveHeight()
        var frame = screen.frame
        frame.size.height = max(1, frame.height - height)
        panel.setFrame(frame, display: true)
        generation += 1
        let request = generation


        if panel.isKeyWindow, lastContentIdentifier == id {
            NotificationCenter.default.post(name: .willHideWindow, object: nil)
            let duration =
                Double(Constants.menuBarPopupAnimationDurationInMilliseconds)
                / 1000.0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                guard request == generation else { return }
                panel.orderOut(nil)
                lastContentIdentifier = nil
            }
            return
        }

        let isContentChange =
            panel.isKeyWindow
            && (lastContentIdentifier != nil && lastContentIdentifier != id)
        lastContentIdentifier = id

        if let hidingPanel = panel as? HidingPanel {
            hidingPanel.hideTimer?.invalidate()
            hidingPanel.hideTimer = nil
        }

        if panel.isKeyWindow {
            NotificationCenter.default.post(
                name: .willChangeContent, object: nil)
            let baseDuration =
                Double(Constants.menuBarPopupAnimationDurationInMilliseconds)
                / 1000.0
            let duration = isContentChange ? baseDuration / 2 : baseDuration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                guard request == generation else { return }
                panel.contentView = VibrancyHostingView(
                    rootView:
                        ZStack {
                            MenuBarPopupView(screenWidth: screen.frame.width) {
                                content()
                            }
                            .position(x: rect.midX)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(UUID())
                )
                panel.makeKeyAndOrderFront(nil)
                DispatchQueue.main.async {
                    guard request == generation else { return }
                    NotificationCenter.default.post(
                        name: .willShowWindow, object: nil)
                }
            }
        } else {
            panel.contentView = VibrancyHostingView(
                rootView:
                    ZStack {
                        MenuBarPopupView(screenWidth: screen.frame.width) {
                            content()
                        }
                        .position(x: rect.midX)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            )
            panel.makeKeyAndOrderFront(nil)
            DispatchQueue.main.async {
                guard request == generation else { return }
                NotificationCenter.default.post(
                    name: .willShowWindow, object: nil)
            }
        }
    }

    static func setup() {
        guard panel == nil, let screen = NSScreen.screens.first?.frame else { return }
        let panelFrame = NSRect(
            x: screen.minX,
            y: screen.minY,
            width: screen.size.width,
            height: screen.size.height
        )

        let newPanel = HidingPanel(
            contentRect: panelFrame,
            // A titled panel reserves a title-bar safe area even when its title
            // is hidden, adding unwanted space above the popup.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newPanel.level = NSWindow.Level(
            rawValue: Int(CGWindowLevelForKey(.floatingWindow)))
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.collectionBehavior = [.canJoinAllSpaces]

        panel = newPanel
    }
}
