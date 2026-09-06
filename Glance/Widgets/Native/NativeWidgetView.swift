import SwiftUI

private struct NativeHostedView: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class NativeWidgetRuntime: ObservableObject {
    @Published private(set) var barView: NSView?
    @Published private(set) var error: String?
    @Published private(set) var manifest: NativeWidgetManifest?
    private var widget: GlanceWidgetExtension?
    private var popupView: NSView?
    private var activeID: String?
    private var observer: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    var openPopup: (() -> Void)?

    func configure(id: String, config: ConfigData, appearance: AppearanceConfig, height: CGFloat) {
        precondition(Thread.isMainThread)
        do {
            let identifier = String(id.dropFirst("native.".count))
            guard identifier.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil else {
                throw NativeWidgetError.invalidManifest
            }
            let url: URL
            if let path = config["bundle"]?.stringValue {
                url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
            } else {
                guard let installed = NativeWidgetManifest.installed().first(where: { $0.id == identifier }) else {
                    throw NativeWidgetError.missingBundle
                }
                url = installed.url
            }
            let metadata = try NativeWidgetManifest(url: url)
            let dataDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/glance/widgets/\(identifier)", isDirectory: true)
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            let context: NSDictionary = [
                "id": id,
                "config": config.mapValues { $0.widgetFoundationValue },
                "foregroundColor": NSColor(appearance.foregroundColor),
                "accentColor": NSColor(appearance.accentColor),
                "barHeight": Double(height),
                "bundleURL": metadata.url as NSURL,
                "dataDirectoryURL": dataDirectory as NSURL,
            ]

            if let widget, manifest?.url == metadata.url, activeID == id {
                widget.update(with: context)
                return
            }
            stop()
            let instance = try NativeWidgetLoader.shared.instantiate(metadata)
            widget = instance
            manifest = metadata
            activeID = id
            observer = NotificationCenter.default.addObserver(
                forName: glanceWidgetOpenPopup, object: instance, queue: .main
            ) { [weak self] _ in self?.openPopup?() }
            terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.stop() }
            instance.start(with: context)
            barView = instance.makeBarView()
            error = nil
        } catch {
            stop()
            self.error = error.localizedDescription
            AppLogger.shared.warning("Native widget \(id): \(error.localizedDescription)", category: .app)
        }
    }

    func makePopupView() -> NSView? {
        if let popupView { return popupView }
        popupView = widget?.makePopupView()
        return popupView
    }

    func stop() {
        if let activeID { MenuBarPopup.dismiss(id: "native-popup.\(activeID)") }
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        observer = nil
        terminationObserver = nil
        widget?.stop()
        widget = nil
        barView = nil
        popupView = nil
        manifest = nil
        activeID = nil
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
    }
}

struct NativeWidgetView: View {
    let id: String
    let config: ConfigData
    @ObservedObject private var configManager = ConfigManager.shared
    @StateObject private var runtime = NativeWidgetRuntime()
    @State private var rect = CGRect.zero
    @State private var mounted = false

    private var configurationSignature: Data {
        (try? JSONSerialization.data(withJSONObject: config.mapValues { $0.widgetFoundationValue }, options: [.sortedKeys])) ?? Data()
    }

    private var height: CGFloat {
        let height = configManager.config.experimental.foreground.resolveHeight()
        return height < 45 ? max(height - 4, 24) : 38
    }

    var body: some View {
        Group {
            if let view = runtime.barView, let manifest = runtime.manifest {
                NativeHostedView(view: view)
                    .frame(width: manifest.barWidth, height: height)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help(runtime.error ?? "Loading widget…")
            }
        }
        .experimentalConfiguration(horizontalPadding: 0)
        .frame(maxHeight: .infinity)
        .background(GeometryReader { geometry in
            Color.clear
                .onAppear { rect = geometry.frame(in: .global) }
                .onChange(of: geometry.frame(in: .global)) { _, value in rect = value }
        })
        .onAppear {
            mounted = true
            refresh()
        }
        .onDisappear {
            mounted = false
            runtime.openPopup = nil
            runtime.stop()
        }
        .onChange(of: configurationSignature) { _, _ in
            if mounted { refresh() }
        }
        .onChange(of: configManager.config.appearance.foregroundColor) { _, _ in
            if mounted { refresh() }
        }
        .onChange(of: configManager.config.appearance.accentColor) { _, _ in
            if mounted { refresh() }
        }
        .onChange(of: height) { _, _ in
            if mounted { refresh() }
        }
    }

    private func refresh() {
        runtime.openPopup = {
            guard let manifest = runtime.manifest, let popup = runtime.makePopupView() else { return }
            MenuBarPopup.show(rect: rect, id: "native-popup.\(id)") {
                NativeHostedView(view: popup)
                    .frame(width: manifest.popupWidth, height: manifest.popupHeight)
            }
        }
        runtime.configure(id: id, config: config,
                          appearance: configManager.config.appearance, height: height)
    }
}

private extension TOMLValue {
    var widgetFoundationValue: Any {
        switch self {
        case .string(let value): return value
        case .bool(let value): return value
        case .int(let value): return value
        case .double(let value): return value
        case .array(let values): return values.map { $0.widgetFoundationValue }
        case .dictionary(let values): return values.mapValues { $0.widgetFoundationValue }
        case .null: return NSNull()
        }
    }
}
