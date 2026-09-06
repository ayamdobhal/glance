import AppKit
import Combine
import Foundation

class SpacesViewModel: ObservableObject {
    static let shared = SpacesViewModel()
    @Published var spaces: [AnySpace] = []
    @Published var isUnavailable = false
    private var timer: Timer?
    private var provider: AnySpacesProvider?
    private var appLaunchObserver: NSObjectProtocol?
    private var appTerminateObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?

    init() {
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
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        // Poll at 1s — spaces don't change that fast; event-driven refresh handles responsiveness
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            self?.loadSpaces()
        }
        timer?.tolerance = 0.2

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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                let provider = self.provider
            else {
                DispatchQueue.main.async {
                    self?.spaces = []
                }
                return
            }

            guard let spaces = provider.getSpacesWithWindows() else {
                DispatchQueue.main.async {
                    self.spaces = []
                    self.isUnavailable = true
                }
                return
            }

            let sortedSpaces = spaces.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
            DispatchQueue.main.async {
                if self.isUnavailable { self.isUnavailable = false }
                // Only publish if spaces actually changed — avoids unnecessary SwiftUI re-renders
                if self.spaces != sortedSpaces {
                    self.spaces = sortedSpaces
                }
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
