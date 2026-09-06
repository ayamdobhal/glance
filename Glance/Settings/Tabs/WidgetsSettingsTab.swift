import SwiftUI
import UniformTypeIdentifiers

/// Wrapper giving each widget row a stable UUID identity for drag-and-drop.
private struct IdentifiedWidget: Identifiable, Equatable {
    let id = UUID()
    var item: TomlWidgetItem

    static func == (lhs: IdentifiedWidget, rhs: IdentifiedWidget) -> Bool {
        lhs.id == rhs.id
    }
}

struct WidgetsSettingsTab: View {
    @ObservedObject var configManager = ConfigManager.shared
    @State private var activeWidgets: [IdentifiedWidget] = []
    @State private var draggedItem: IdentifiedWidget?
    @State private var installedNativeWidgets = NativeWidgetManifest.installed()

    @State private var batteryShowPercentage = true
    @State private var batteryWarningLevel = 30
    @State private var batteryCriticalLevel = 10

    @State private var volumeShowPercentage = false
    @State private var volumeScrollStep = 3.0

    @State private var brightnessShowPercentage = false
    @State private var brightnessScrollStep = 3.0

    @State private var weatherProvider = "met-no"
    @State private var weatherUseIPFallback = true
    @State private var weatherUsesManualLocation = false
    @State private var weatherLocationName = ""
    @State private var weatherLatitude = ""
    @State private var weatherLongitude = ""

    private var allAvailableWidgets: [(id: String, label: String, icon: String)] { [
        ("default.spaces", "Spaces", "rectangle.3.group"),
        ("default.activeapp", "Active App", "app.badge.fill"),
        ("default.nowplaying", "Now Playing", "music.note"),
        ("default.volume", "Volume", "speaker.wave.2"),
        ("default.network", "Network", "wifi"),
        ("default.battery", "Battery", "battery.75percent"),
        ("default.weather", "Weather", "cloud.sun"),
        ("default.systemmonitor", "System Monitor", "gauge.medium"),
        ("default.disk", "Disk", "internaldrive"),
        ("default.pomodoro", "Pomodoro", "timer"),
        ("default.inputlanguage", "Input Language", "keyboard"),
        ("default.brightness", "Brightness", "sun.max"),
        ("default.clipboard", "Clipboard", "doc.on.clipboard"),
        ("default.bluetooth", "Bluetooth", "wave.3.right"),
        ("default.time", "Time", "clock"),
        ("spacer", "Spacer", "arrow.left.and.right"),
        ("divider", "Divider", "minus"),
    ] + installedNativeWidgets.map { ("native.\($0.id)", $0.name, "puzzlepiece.extension") } }

    private let weatherProviders: [(id: String, label: String)] = [
        ("met-no", "MET Norway"),
        ("open-meteo", "Open-Meteo"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSection(title: "Active Widgets") {
                    Text("Drag to reorder. Click - to remove.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(activeWidgets) { widget in
                        let index = activeWidgets.firstIndex(where: { $0.id == widget.id })!
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)

                            Image(systemName: iconFor(widget.item.id))
                                .frame(width: 20)

                            Text(labelFor(widget.item.id))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button(action: {
                                removeWidget(widget)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)

                            Button(action: { moveWidget(widget, direction: -1) }) {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)

                            Button(action: { moveWidget(widget, direction: 1) }) {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.plain)
                            .disabled(index == activeWidgets.count - 1)
                        }
                        .padding(.vertical, 4)
                        .onDrag {
                            draggedItem = widget
                            return NSItemProvider(object: widget.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: WidgetDropDelegate(
                            targetItem: widget,
                            activeWidgets: $activeWidgets,
                            draggedItem: $draggedItem,
                            onDrop: { writeWidgetList() }
                        ))
                    }
                }

                SettingsSection(title: "Add Widget") {
                    HStack {
                        Button("Open Widgets Folder") {
                            try? FileManager.default.createDirectory(at: NativeWidgetManifest.directory, withIntermediateDirectories: true)
                            NSWorkspace.shared.open(NativeWidgetManifest.directory)
                        }
                        Button("Refresh Widgets") {
                            installedNativeWidgets = NativeWidgetManifest.installed()
                        }
                    }
                    Text("Native widgets run code with Glance’s permissions. Add only widgets you trust. Restart Glance after rebuilding a widget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let inactive = allAvailableWidgets.filter { widget in
                        if widget.id == "spacer" || widget.id == "divider" { return true }
                        return !activeWidgets.contains(where: { $0.item.id == widget.id })
                    }

                    if inactive.isEmpty {
                        Text("All widgets are active")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(inactive, id: \.id) { widget in
                            HStack {
                                Image(systemName: widget.icon)
                                    .frame(width: 20)
                                Text(widget.label)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button(action: {
                                    addWidget(widget.id)
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                SettingsSection(title: "Battery") {
                    Toggle("Show percentage in bar", isOn: $batteryShowPercentage)
                        .onChange(of: batteryShowPercentage) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.battery.show-percentage",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    StepperRow(
                        label: "Warning level",
                        value: $batteryWarningLevel,
                        range: 5...80,
                        suffix: "%"
                    ) {
                        clampBatteryThresholds(changed: .warning)
                    }

                    StepperRow(
                        label: "Critical level",
                        value: $batteryCriticalLevel,
                        range: 1...50,
                        suffix: "%"
                    ) {
                        clampBatteryThresholds(changed: .critical)
                    }

                    Text("These thresholds control low-battery colors in the bar and popup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "Volume") {
                    Toggle("Show percentage in bar", isOn: $volumeShowPercentage)
                        .onChange(of: volumeShowPercentage) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.volume.show-percentage",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    SliderRow(
                        label: "Scroll step",
                        value: $volumeScrollStep,
                        range: 1...10,
                        step: 1,
                        format: "%.0f%%"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.volume.scroll-step",
                            newValue: String(Int(volumeScrollStep.rounded()))
                        )
                    }

                    Text("Mouse wheel changes system volume by this amount.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "Brightness") {
                    Toggle("Show percentage in bar", isOn: $brightnessShowPercentage)
                        .onChange(of: brightnessShowPercentage) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.brightness.show-percentage",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    SliderRow(
                        label: "Scroll step",
                        value: $brightnessScrollStep,
                        range: 1...10,
                        step: 1,
                        format: "%.0f%%"
                    ) {
                        configManager.updateConfigValue(
                            key: "widgets.default.brightness.scroll-step",
                            newValue: String(Int(brightnessScrollStep.rounded()))
                        )
                    }

                    Text("Mouse wheel changes display brightness by this amount when control is available.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsSection(title: "Weather") {
                    HStack {
                        Text("Provider")
                            .frame(width: 130, alignment: .leading)
                        Picker("Provider", selection: $weatherProvider) {
                            ForEach(weatherProviders, id: \.id) { provider in
                                Text(provider.label).tag(provider.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: weatherProvider) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.weather.provider",
                                newValue: newValue
                            )
                        }
                    }

                    Toggle("Use IP fallback when system location fails", isOn: $weatherUseIPFallback)
                        .onChange(of: weatherUseIPFallback) { _, newValue in
                            configManager.updateConfigValue(
                                key: "widgets.default.weather.use-ip-fallback",
                                newValue: newValue ? "true" : "false"
                            )
                        }

                    Toggle("Use manual coordinates", isOn: $weatherUsesManualLocation)
                        .onChange(of: weatherUsesManualLocation) { _, enabled in
                            if !enabled {
                                clearWeatherManualLocation()
                            }
                        }

                    if weatherUsesManualLocation {
                        HStack {
                            Text("Location name")
                                .frame(width: 130, alignment: .leading)
                            TextField("Optional", text: $weatherLocationName)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            Text("Latitude")
                                .frame(width: 130, alignment: .leading)
                            TextField("55.7558", text: $weatherLatitude)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            Text("Longitude")
                                .frame(width: 130, alignment: .leading)
                            TextField("37.6173", text: $weatherLongitude)
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack {
                            Spacer()
                            Button("Apply Manual Location") {
                                commitWeatherManualLocation()
                            }
                            .disabled(parsedWeatherLatitude == nil || parsedWeatherLongitude == nil)
                        }
                    }

                    Text("Manual coordinates give the most stable weather if macOS location is inconsistent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Time and Spaces keep their own dedicated settings tabs. Any new configurable widget should get a section here instead of staying TOML-only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(24)
        }
        .onAppear { syncAll() }
        .onReceive(configManager.$config) { _ in
            // Only sync per-widget settings — NOT the widget list.
            // The widget list is owned by this tab's local state and written
            // back to config on every change. Re-syncing it from onReceive
            // causes a feedback loop (local change → file write → file watcher
            // reload → onReceive overwrites local state with stale config).
            syncWidgetSettings()
        }
    }

    // MARK: - Sync

    private func syncAll() {
        syncWidgetList()
        syncWidgetSettings()
    }

    private func syncWidgetList() {
        activeWidgets = configManager.config.rootToml.widgets.displayed
            .map { IdentifiedWidget(item: $0) }
    }

    private func syncWidgetSettings() {
        let batteryConfig = configManager.globalWidgetConfig(for: "default.battery")
        batteryShowPercentage = batteryConfig["show-percentage"]?.boolValue ?? true
        batteryWarningLevel = batteryConfig["warning-level"]?.intValue ?? 30
        batteryCriticalLevel = batteryConfig["critical-level"]?.intValue ?? 10

        let volumeConfig = configManager.globalWidgetConfig(for: "default.volume")
        volumeShowPercentage = volumeConfig["show-percentage"]?.boolValue ?? false
        volumeScrollStep = volumeConfig["scroll-step"]?.doubleValue ?? 3

        let brightnessConfig = configManager.globalWidgetConfig(for: "default.brightness")
        brightnessShowPercentage = brightnessConfig["show-percentage"]?.boolValue ?? false
        brightnessScrollStep = brightnessConfig["scroll-step"]?.doubleValue ?? 3

        let weatherConfig = configManager.globalWidgetConfig(for: "default.weather")
        weatherProvider = weatherConfig["provider"]?.stringValue ?? "met-no"
        weatherUseIPFallback = weatherConfig["use-ip-fallback"]?.boolValue ?? true

        let weatherLocationConfig = weatherConfig["location"]?.dictionaryValue ?? [:]
        weatherUsesManualLocation =
            weatherLocationConfig["latitude"]?.doubleValue != nil
            && weatherLocationConfig["longitude"]?.doubleValue != nil
        weatherLocationName = weatherLocationConfig["name"]?.stringValue ?? ""
        weatherLatitude = decimalString(from: weatherLocationConfig["latitude"]?.doubleValue)
        weatherLongitude = decimalString(from: weatherLocationConfig["longitude"]?.doubleValue)
    }

    // MARK: - Widget list operations

    private func labelFor(_ id: String) -> String {
        allAvailableWidgets.first(where: { $0.id == id })?.label ?? id
    }

    private func iconFor(_ id: String) -> String {
        allAvailableWidgets.first(where: { $0.id == id })?.icon ?? "questionmark"
    }

    private func removeWidget(_ widget: IdentifiedWidget) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeWidgets.removeAll(where: { $0.id == widget.id })
        }
        writeWidgetList()
    }

    private func addWidget(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activeWidgets.append(IdentifiedWidget(item: TomlWidgetItem(id: id, inlineParams: [:])))
        }
        writeWidgetList()
    }

    private func moveWidget(_ widget: IdentifiedWidget, direction: Int) {
        guard let index = activeWidgets.firstIndex(where: { $0.id == widget.id }) else { return }
        let newIndex = index + direction
        guard newIndex >= 0, newIndex < activeWidgets.count else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            activeWidgets.swapAt(index, newIndex)
        }
        writeWidgetList()
    }

    private func writeWidgetList() {
        let listItems = activeWidgets
            .map { "    \(serializeWidgetItem($0.item))" }
            .joined(separator: ",\n")
        let listString = listItems.isEmpty ? "[]" : "[\n\(listItems)\n]"
        configManager.updateConfigValue(
            key: "widgets.displayed",
            newValue: listString)
    }

    // MARK: - TOML serialization

    private func serializeWidgetItem(_ item: TomlWidgetItem) -> String {
        if item.inlineParams.isEmpty {
            return quote(item.id)
        }

        return "{ \(serializeKey(item.id)) = \(serializeInlineTable(item.inlineParams)) }"
    }

    private func serializeInlineTable(_ dict: ConfigData) -> String {
        let pairs = dict.keys.sorted().map { key in
            "\(serializeKey(key)) = \(serializeTOMLValue(dict[key] ?? .null))"
        }
        return "{ \(pairs.joined(separator: ", ")) }"
    }

    private func serializeTOMLValue(_ value: TOMLValue) -> String {
        switch value {
        case .string(let string):
            return quote(string)
        case .bool(let bool):
            return bool ? "true" : "false"
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .array(let array):
            return "[\(array.map(serializeTOMLValue).joined(separator: ", "))]"
        case .dictionary(let dict):
            return serializeInlineTable(dict)
        case .null:
            return quote("")
        }
    }

    private func quote(_ string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func serializeKey(_ key: String) -> String {
        let bareKeyPattern = #"^[A-Za-z0-9_-]+$"#
        if key.range(of: bareKeyPattern, options: .regularExpression) != nil {
            return key
        }
        return quote(key)
    }

    // MARK: - Battery thresholds

    private enum BatteryThresholdChange {
        case warning
        case critical
    }

    private func clampBatteryThresholds(changed: BatteryThresholdChange) {
        switch changed {
        case .warning:
            if batteryWarningLevel <= batteryCriticalLevel {
                batteryCriticalLevel = max(1, batteryWarningLevel - 5)
            }
        case .critical:
            if batteryCriticalLevel >= batteryWarningLevel {
                batteryWarningLevel = min(80, batteryCriticalLevel + 5)
            }
        }

        configManager.updateConfigValues(pairs: [
            (key: "widgets.default.battery.warning-level", value: String(batteryWarningLevel)),
            (key: "widgets.default.battery.critical-level", value: String(batteryCriticalLevel)),
        ])
    }

    // MARK: - Weather manual location

    private var parsedWeatherLatitude: Double? {
        parseDecimal(weatherLatitude)
    }

    private var parsedWeatherLongitude: Double? {
        parseDecimal(weatherLongitude)
    }

    private func commitWeatherManualLocation() {
        guard let latitude = parsedWeatherLatitude, let longitude = parsedWeatherLongitude else { return }

        configManager.updateConfigValues(pairs: [
            (
                key: "widgets.default.weather.location.latitude",
                value: String(format: "%.4f", latitude)
            ),
            (
                key: "widgets.default.weather.location.longitude",
                value: String(format: "%.4f", longitude)
            ),
        ])

        let trimmedName = weatherLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            configManager.removeConfigValue(key: "widgets.default.weather.location.name")
        } else {
            configManager.updateConfigValue(
                key: "widgets.default.weather.location.name",
                newValue: trimmedName
            )
        }
    }

    private func clearWeatherManualLocation() {
        configManager.removeConfigValues(keys: [
            "widgets.default.weather.location.latitude",
            "widgets.default.weather.location.longitude",
            "widgets.default.weather.location.name",
        ])
    }

    private func parseDecimal(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    private func decimalString(from value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.4f", value)
    }
}

// MARK: - Drop Delegate (stable identity based)

private struct WidgetDropDelegate: DropDelegate {
    let targetItem: IdentifiedWidget
    @Binding var activeWidgets: [IdentifiedWidget]
    @Binding var draggedItem: IdentifiedWidget?
    let onDrop: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedItem,
              dragged.id != targetItem.id,
              let fromIndex = activeWidgets.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = activeWidgets.firstIndex(where: { $0.id == targetItem.id })
        else { return }

        withAnimation(.easeInOut(duration: 0.15)) {
            activeWidgets.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        onDrop()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

// MARK: - Stepper Row

private struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String
    let onCommit: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 130, alignment: .leading)
            Stepper(value: $value, in: range) {
                Text("\(value)\(suffix)")
                    .monospacedDigit()
            }
            .onChange(of: value) { _, _ in
                onCommit()
            }
            Spacer()
        }
    }
}
