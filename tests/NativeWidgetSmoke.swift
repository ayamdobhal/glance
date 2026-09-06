import AppKit

@main
struct NativeWidgetSmoke {
    static func main() throws {
        _ = NSApplication.shared
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let manifest = try NativeWidgetManifest(url: url)
        assert(manifest.id == "counter")
        assert(manifest.barWidth == 100)
        let instance = try NativeWidgetLoader.shared.instantiate(manifest)
        let context: NSDictionary = [
            "id": "native.counter", "config": ["title": "Smoke test"],
            "foregroundColor": NSColor.white, "accentColor": NSColor.cyan,
            "barHeight": 38.0,
        ]
        instance.start(with: context)
        let bar = instance.makeBarView()
        guard let popup = instance.makePopupView() else { fatalError("Missing popup") }
        assert(bar !== popup)
        bar.setFrameSize(NSSize(width: 100, height: 38))
        popup.setFrameSize(NSSize(width: 300, height: 240))
        bar.layoutSubtreeIfNeeded()
        popup.layoutSubtreeIfNeeded()
        instance.update(with: ["config": ["title": "Changed"], "accentColor": NSColor.orange])
        instance.stop()
        // Each configured widget gets its own instance; loaded code is reused.
        let second = try NativeWidgetLoader.shared.instantiate(manifest)
        assert((instance as AnyObject) !== (second as AnyObject))
        second.start(with: context)
        second.stop()

        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        var info = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: url.appendingPathComponent("Contents/Info.plist")), format: nil) as! [String: Any]
        func rejected() throws {
            let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            try data.write(to: temporary.appendingPathComponent("Contents/Info.plist"))
            do {
                _ = try NativeWidgetManifest(url: temporary)
                fatalError("Invalid manifest was accepted")
            } catch NativeWidgetError.invalidManifest {}
        }
        info["GlanceWidgetAPIVersion"] = 2
        try rejected()
        info["GlanceWidgetAPIVersion"] = 1
        info["GlanceWidgetIdentifier"] = "../escape"
        try rejected()
        info["GlanceWidgetIdentifier"] = "counter"
        info["GlanceWidgetBarWidth"] = -10
        try rejected()
        print("Native widget smoke checks passed: independent bundle loading, views, lifecycle, instance isolation, invalid manifests.")
    }
}
