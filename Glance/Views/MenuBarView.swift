import SwiftUI

struct MenuBarView: View {
    @ObservedObject var configManager = ConfigManager.shared

    var body: some View {
        let items = configManager.config.rootToml.widgets.displayed
        let appearance = configManager.config.appearance
        let fg = configManager.config.experimental.foreground
        let formation = fg.formation

        Group {
            switch formation {
            case .full:
                fullBar(items: items, appearance: appearance, fg: fg)
            case .floating:
                floatingBar(items: items, appearance: appearance, fg: fg)
            case .islands:
                islandsBar(items: items, appearance: appearance, fg: fg)
            case .pills:
                pillsBar(items: items, appearance: appearance, fg: fg)
            }
        }
        .foregroundStyle(appearance.foregroundColor)
        .frame(height: max(fg.resolveHeight(), 1.0))
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.001))
        .contextMenu {
            Button("Settings...") {
                SettingsWindowController.shared.showSettings()
            }
            Divider()
            Button("Quit Glance") {
                NSApplication.shared.terminate(nil)
            }
        }
        .environment(\.barStyle, configManager.config.barStyle)
        .environment(\.appearance, appearance)
        .preferredColorScheme(.dark)
    }

    // MARK: - Full Monobar (flat menubar — no rounding, no border)

    @ViewBuilder
    private func fullBar(items: [TomlWidgetItem], appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        HStack(spacing: 0) {
            widgetContent(items: items, fg: fg)
        }
        .padding(.horizontal, fg.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appearance.widgetBackgroundColor.opacity(appearance.fillOpacity))
    }

    // MARK: - Floating Monobar

    @ViewBuilder
    private func floatingBar(items: [TomlWidgetItem], appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        HStack(spacing: 0) {
            widgetContent(items: items, fg: fg)
        }
        .padding(.horizontal, fg.horizontalPadding)
        .frame(maxWidth: .infinity)
        .frame(height: capsuleHeight(fg))
        .widgetStyle(appearance, heightOverride: capsuleHeight(fg))
        .padding(.horizontal, fg.margin)
    }

    // MARK: - Islands (Current Behavior)

    @ViewBuilder
    private func islandsBar(items: [TomlWidgetItem], appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        let sections = splitBySpacer(items)
        let hasBanner = items.contains(where: { $0.id == "system-banner" })

        Group {
            if sections.count == 3 {
                ZStack {
                    HStack(spacing: fg.spacing) {
                        widgetRow(sections[0])
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: fg.spacing) {
                        widgetRow(sections[1])
                    }

                    HStack(spacing: fg.spacing) {
                        Spacer(minLength: 0)
                        widgetRow(sections[2])
                        if !hasBanner {
                            SystemBannerWidget(withLeftPadding: true)
                        }
                    }
                }
            } else {
                HStack(spacing: fg.spacing) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        buildView(for: item)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                    if !hasBanner {
                        SystemBannerWidget(withLeftPadding: true)
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: items.map(\.id))
        .padding(.horizontal, fg.horizontalPadding)
    }

    // MARK: - Pills (Grouped by Spacers)

    @ViewBuilder
    private func pillsBar(items: [TomlWidgetItem], appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        let groups = splitIntoGroups(items)
        let height = capsuleHeight(fg)
        let nonSpacerGroups = groups.filter { !$0.isSpacer }
        let spacerCount = groups.filter { $0.isSpacer }.count
        let hasBanner = items.contains(where: { $0.id == "system-banner" })

        Group {
            if spacerCount == 2 && nonSpacerGroups.count == 3 {
                ZStack {
                    HStack(spacing: fg.gap) {
                        pillCapsule(nonSpacerGroups[0], height: height, appearance: appearance, fg: fg)
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: fg.gap) {
                        pillCapsule(nonSpacerGroups[1], height: height, appearance: appearance, fg: fg)
                    }

                    HStack(spacing: fg.gap) {
                        Spacer(minLength: 0)
                        pillCapsule(nonSpacerGroups[2], height: height, appearance: appearance, fg: fg)
                        if !hasBanner {
                            SystemBannerWidget(withLeftPadding: false)
                        }
                    }
                }
            } else {
                HStack(spacing: fg.gap) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        if group.isSpacer {
                            Spacer(minLength: 0)
                        } else {
                            pillCapsule(group, height: height, appearance: appearance, fg: fg)
                        }
                    }
                    if !hasBanner {
                        SystemBannerWidget(withLeftPadding: false)
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: items.map(\.id))
        .padding(.horizontal, fg.margin)
    }

    @ViewBuilder
    private func pillCapsule(_ group: WidgetGroup, height: CGFloat, appearance: AppearanceConfig, fg: ForegroundConfig) -> some View {
        HStack(spacing: fg.spacing) {
            ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                buildView(for: item)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: height)
        .widgetStyle(appearance, heightOverride: height)
    }

    // MARK: - Shared Helpers

    private func capsuleHeight(_ fg: ForegroundConfig) -> CGFloat {
        let h = fg.resolveHeight()
        return h < 45 ? max(h - 4, 24) : 38
    }

    /// Splits widget items into sections separated by spacers.
    private func splitBySpacer(_ items: [TomlWidgetItem]) -> [[TomlWidgetItem]] {
        var sections: [[TomlWidgetItem]] = [[]]
        for item in items {
            if item.id == "spacer" {
                sections.append([])
            } else {
                sections[sections.count - 1].append(item)
            }
        }
        return sections
    }

    @ViewBuilder
    private func widgetRow(_ items: [TomlWidgetItem]) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            buildView(for: item)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    @ViewBuilder
    private func widgetContent(items: [TomlWidgetItem], fg: ForegroundConfig) -> some View {
        let sections = splitBySpacer(items)
        let hasBanner = items.contains(where: { $0.id == "system-banner" })

        if sections.count == 3 {
            // True center: left pushes left, center stays centered, right pushes right
            ZStack {
                HStack(spacing: fg.spacing) {
                    widgetRow(sections[0])
                    Spacer(minLength: 0)
                }

                HStack(spacing: fg.spacing) {
                    widgetRow(sections[1])
                }

                HStack(spacing: fg.spacing) {
                    Spacer(minLength: 0)
                    widgetRow(sections[2])
                    if !hasBanner {
                        SystemBannerWidget(withLeftPadding: true)
                    }
                }
            }
            .animation(.smooth(duration: 0.3), value: items.map(\.id))
        } else {
            HStack(spacing: fg.spacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    buildView(for: item)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(.smooth(duration: 0.3), value: items.map(\.id))

            if !hasBanner {
                SystemBannerWidget(withLeftPadding: true)
            }
        }
    }

    // MARK: - Group Splitting (for Pills)

    private struct WidgetGroup {
        let items: [TomlWidgetItem]
        let isSpacer: Bool

        static func spacer() -> WidgetGroup {
            WidgetGroup(items: [], isSpacer: true)
        }
    }

    private func splitIntoGroups(_ items: [TomlWidgetItem]) -> [WidgetGroup] {
        var groups: [WidgetGroup] = []
        var currentGroup: [TomlWidgetItem] = []

        for item in items {
            if item.id == "spacer" {
                if !currentGroup.isEmpty {
                    groups.append(WidgetGroup(items: currentGroup, isSpacer: false))
                    currentGroup = []
                }
                groups.append(.spacer())
            } else if item.id == "divider" {
                // Dividers become thin separators within a pill group
                currentGroup.append(item)
            } else {
                currentGroup.append(item)
            }
        }

        if !currentGroup.isEmpty {
            groups.append(WidgetGroup(items: currentGroup, isSpacer: false))
        }

        return groups
    }

    // MARK: - Widget Builder

    @ViewBuilder
    private func buildView(for item: TomlWidgetItem) -> some View {
        let config = ConfigProvider(
            config: configManager.resolvedWidgetConfig(for: item))

        switch item.id {
        case "default.spaces":
            SpacesWidget().environmentObject(config)

        case "default.network":
            NetworkWidget().environmentObject(config)

        case "default.battery":
            BatteryWidget().environmentObject(config)

        case "default.time":
            TimeWidget(configProvider: config)

        case "default.nowplaying":
            NowPlayingWidget()
                .environmentObject(config)

        case "default.volume":
            VolumeWidget().environmentObject(config)

        case "default.activeapp":
            ActiveAppWidget().environmentObject(config)

        case "default.weather":
            WeatherWidget().environmentObject(config)

        case "default.systemmonitor":
            SystemMonitorWidget().environmentObject(config)

        case "default.disk":
            DiskWidget().environmentObject(config)

        case "default.pomodoro":
            PomodoroWidget().environmentObject(config)

        case "default.inputlanguage":
            InputLanguageWidget()

        case "default.brightness":
            BrightnessWidget().environmentObject(config)

        case "default.clipboard":
            ClipboardWidget().environmentObject(config)

        case "default.bluetooth":
            BluetoothWidget().environmentObject(config)

        case "spacer":
            Spacer().frame(minWidth: 50, maxWidth: .infinity)

        case "divider":
            Rectangle()
                .fill(configManager.config.appearance.accentColor.opacity(0.4))
                .frame(width: 2, height: 15)
                .clipShape(Capsule())

        case "system-banner":
            SystemBannerWidget()

        default:
            if item.id.hasPrefix("native.") {
                NativeWidgetView(id: item.id, config: config.config)
            } else if item.id.hasPrefix("script.") {
                let command = config.config["command"]?.stringValue ?? ""
                let interval = config.config["interval"]?.intValue ?? 10
                ScriptWidget(command: command, interval: TimeInterval(interval))
            } else {
                Text("?\(item.id)?").foregroundColor(.red)
            }
        }
    }
}
