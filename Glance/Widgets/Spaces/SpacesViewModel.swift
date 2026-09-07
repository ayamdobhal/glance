import AppKit
import Combine
import Foundation

class SpacesViewModel: ObservableObject {
    static let shared = SpacesViewModel()
    @Published var spaces: [AnySpace] = []
    @Published var isUnavailable = false
    private var timer: Timer?
    private var provider: AnySpacesProvider?
    private var refreshGeneration = 0
    private var isLoading = false
    private var appLaunchObserver: NSObjectProtocol?
    private var appTerminateObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?

    init() {
        selectProvider()
        startMonitoring()
    }

    private func selectProvider() {
        let runningApps = NSWorkspace.shared.runningApplications.compactMap {
            $0.localizedName?.lowercased()
        }
        if runningApps.contains("yabai") {
            provider = AnySpacesProvider(YabaiSpacesProvider())
        } else if runningApps.contains("aerospace") {
            provider = AnySpacesProvider(AerospaceSpacesProvider())
        } else {
            provider = AnySpacesProvider(NativeSpacesProvider())
        }
    }

    func refreshAfterDisplayChange() {
        precondition(Thread.isMainThread)
        refreshGeneration += 1
        isLoading = false
        stopMonitoring()
        selectProvider()
        spaces = []
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        // Poll at 1s — spaces don't change that fast; event-driven refresh handles responsiveness
        timer = Timer(timeInterval: 1.0, repeats: true) {
            [weak self] _ in
            self?.loadSpaces()
        }
        timer?.tolerance = 0.2
        if let timer { RunLoop.main.add(timer, forMode: .common) }

        // Immediately refresh on app activation (space switch) for responsiveness
        let center = NSWorkspace.shared.notificationCenter
        activateObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.loadSpaces()
        }
        appLaunchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.loadSpaces()
        }
        appTerminateObserver = center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.loadSpaces()
        }

        loadSpaces()
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        let center = NSWorkspace.shared.notificationCenter
        if let obs = activateObserver { center.removeObserver(obs) }
        if let obs = appLaunchObserver { center.removeObserver(obs) }
        if let obs = appTerminateObserver { center.removeObserver(obs) }
    }

    private func loadSpaces() {
        guard !isLoading, let provider else { return }
        isLoading = true
        let generation = refreshGeneration
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = provider.getSpacesWithWindows()?.sorted {
                $0.id.localizedStandardCompare($1.id) == .orderedAscending
            }
            DispatchQueue.main.async {
                guard let self, generation == self.refreshGeneration else { return }
                self.isLoading = false
                guard let result else {
                    self.spaces = []
                    self.isUnavailable = true
                    return
                }
                self.isUnavailable = false
                if self.spaces != result { self.spaces = result }
            }
        }
    }

    func switchToSpace(_ space: AnySpace, needWindowFocus: Bool = false) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.provider?.focusSpace(
                spaceId: space.id, needWindowFocus: needWindowFocus)
        }
    }

    func switchToWindow(_ window: AnyWindow) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.provider?.focusWindow(windowId: String(window.id))
        }
    }
}

class IconCache {
    static let shared = IconCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() {}
    func icon(for appName: String) -> NSImage? {
        if let cached = cache.object(forKey: appName as NSString) {
            return cached
        }
        let workspace = NSWorkspace.shared
        if let app = workspace.runningApplications.first(where: {
            $0.localizedName == appName
        }),
            let bundleURL = app.bundleURL
        {
            let icon = workspace.icon(forFile: bundleURL.path)
            cache.setObject(icon, forKey: appName as NSString)
            return icon
        }
        return nil
    }
}
