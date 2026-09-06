import AppKit

/// Compile this file with a widget's sources. The versioned Objective-C protocol
/// keeps the boundary independent of Glance's internal Swift types.
@objc(GlanceWidgetExtensionV1)
public protocol GlanceWidgetExtension: NSObjectProtocol {
    init()
    func makeBarView() -> NSView
    func makePopupView() -> NSView?
    func start(with context: NSDictionary)
    func update(with context: NSDictionary)
    func stop()
}

/// All extension methods are called on the main thread. Use background tasks for
/// I/O and cancel them in stop(). Views can be NSHostingView instances containing
/// arbitrary SwiftUI. Request the host's popup with this notification, using the
/// extension instance as its object.
public let glanceWidgetOpenPopup = Notification.Name("GlanceWidgetOpenPopup.v1")

/// Context keys (Foundation/AppKit values only):
/// - id: String, unique configured instance ID, e.g. native.counter
/// - config: NSDictionary, widget-specific TOML settings
/// - foregroundColor / accentColor: NSColor
/// - barHeight: Double, available widget height in points
/// - bundleURL / dataDirectoryURL: NSURL
/// Data directories are per instance and survive upgrades. Never put secrets in
/// TOML; use Keychain or the widget's own credential flow.
