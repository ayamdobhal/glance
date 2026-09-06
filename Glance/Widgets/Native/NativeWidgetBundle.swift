import AppKit

struct NativeWidgetManifest: Identifiable {
    let url: URL
    let id: String
    let name: String
    let barWidth: CGFloat
    let popupWidth: CGFloat
    let popupHeight: CGFloat

    static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/glance/widgets", isDirectory: true)

    init(url: URL) throws {
        self.url = url.standardizedFileURL.resolvingSymlinksInPath()
        let infoURL = self.url.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: infoURL)
        guard let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let version = info["GlanceWidgetAPIVersion"] as? Int, version == 1,
              let id = info["GlanceWidgetIdentifier"] as? String,
              !id.isEmpty,
              id.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil,
              let name = info["CFBundleDisplayName"] as? String,
              info["NSPrincipalClass"] is String else {
            throw NativeWidgetError.invalidManifest
        }
        self.id = id
        self.name = name
        func dimension(_ key: String, fallback: Double, range: ClosedRange<Double>) throws -> CGFloat {
            guard let raw = info[key] else { return CGFloat(fallback) }
            guard let value = raw as? NSNumber, value.doubleValue.isFinite,
                  range.contains(value.doubleValue) else { throw NativeWidgetError.invalidManifest }
            return CGFloat(value.doubleValue)
        }
        barWidth = try dimension("GlanceWidgetBarWidth", fallback: 80, range: 20...600)
        popupWidth = try dimension("GlanceWidgetPopupWidth", fallback: 300, range: 120...900)
        popupHeight = try dimension("GlanceWidgetPopupHeight", fallback: 240, range: 60...900)
    }

    /// Read metadata only. Browsing Settings never executes widget code.
    static func installed() -> [NativeWidgetManifest] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)) ?? []
        var seen = Set<String>()
        return urls.filter { $0.pathExtension == "glancewidget" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? NativeWidgetManifest(url: $0) }
            .filter { seen.insert($0.id).inserted }
    }
}

enum NativeWidgetError: LocalizedError {
    case invalidManifest
    case missingBundle
    case invalidClass

    var errorDescription: String? {
        switch self {
        case .invalidManifest: return "Invalid widget manifest or unsupported API version (expected 1)."
        case .missingBundle: return "Widget bundle was not found. Install it in ~/.config/glance/widgets."
        case .invalidClass: return "Widget does not implement the Glance v1 extension protocol."
        }
    }
}

/// Native code cannot safely be unloaded while Swift/Objective-C types exist.
/// Keep bundles loaded for this process; replacing code requires restarting Glance.
final class NativeWidgetLoader {
    static let shared = NativeWidgetLoader()
    private var classes: [URL: GlanceWidgetExtension.Type] = [:]
    private var bundles: [URL: Bundle] = [:]

    func instantiate(_ manifest: NativeWidgetManifest) throws -> GlanceWidgetExtension {
        precondition(Thread.isMainThread)
        if let type = classes[manifest.url] { return type.init() }
        guard let bundle = Bundle(url: manifest.url) else { throw NativeWidgetError.missingBundle }
        try bundle.loadAndReturnError()
        bundles[manifest.url] = bundle
        guard let type = bundle.principalClass as? GlanceWidgetExtension.Type else {
            throw NativeWidgetError.invalidClass
        }
        classes[manifest.url] = type
        return type.init()
    }
}
