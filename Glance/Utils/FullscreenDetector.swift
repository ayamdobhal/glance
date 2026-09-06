import AppKit
import Foundation

final class FullscreenDetector: ObservableObject {
    @Published var fullscreenDisplayIDs: Set<CGDirectDisplayID> = []

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter

        observers.append(center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.check() })

        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Small delay to let the window settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.check()
            }
        })

        check()
    }

    deinit {
        for obs in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    func check() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        // Skip our own app
        if frontApp.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return
        }

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else {
            fullscreenDisplayIDs = []
            return
        }

        let screens = NSScreen.screens
        guard let primaryTop = screens.first?.frame.maxY else { return }
        var hidden: Set<CGDirectDisplayID> = []

        for info in windowList {
            guard let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat]
            else { continue }

            let window = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0,
                                width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            for screen in screens {
                let frame = DisplayGeometry.accessibilityFrame(screen.frame, primaryTop: primaryTop)
                if window.contains(frame) { hidden.insert(screen.displayID) }
            }
        }
        if fullscreenDisplayIDs != hidden { fullscreenDisplayIDs = hidden }

    }
}
