import SwiftUI

private struct BarDisplayIDKey: EnvironmentKey {
    static let defaultValue: CGDirectDisplayID? = nil
}

extension EnvironmentValues {
    var barDisplayID: CGDirectDisplayID? {
        get { self[BarDisplayIDKey.self] }
        set { self[BarDisplayIDKey.self] = newValue }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

/// Coordinates reported by Accessibility/Core Graphics have their origin at the
/// top-left of the primary screen; AppKit screen coordinates point upward.
enum DisplayGeometry {
    static func accessibilityFrame(_ frame: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryTop - frame.maxY, width: frame.width, height: frame.height)
    }

    static func containingDisplay(for window: CGRect, displays: [CGRect]) -> Int? {
        displays.indices.filter { displays[$0].intersects(window) }.max {
            let a = displays[$0].intersection(window)
            let b = displays[$1].intersection(window)
            return a.width * a.height < b.width * b.height
        }
    }
}

/// The ordered screen list includes the primary screen and coordinate layout.
/// Comparing only IDs misses primary-display changes and window migration.
struct BarDisplayLayout: Equatable {
    let id: CGDirectDisplayID
    let frame: CGRect
}
