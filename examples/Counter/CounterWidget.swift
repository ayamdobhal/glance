import AppKit
import SwiftUI

private final class CounterState: ObservableObject {
    @Published var count = 0
    @Published var title = "Counter"
    @Published var accent = Color.cyan
    @Published var foreground = Color.white
    @Published var automatic = false
    var showPopup: (() -> Void)?
}

/// This bundle is built independently. Nothing in Glance imports its types.
final class CounterWidget: NSObject, GlanceWidgetExtension {
    private let state = CounterState()
    private var timer: Timer?

    override init() { super.init() }

    func start(with context: NSDictionary) {
        update(with: context)
        state.showPopup = { [weak self] in
            guard let self else { return }
            NotificationCenter.default.post(name: glanceWidgetOpenPopup, object: self)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.state.automatic else { return }
            self.state.count += 1
        }
    }

    func update(with context: NSDictionary) {
        let config = context["config"] as? [String: Any] ?? [:]
        state.title = config["title"] as? String ?? "Counter"
        if let color = context["accentColor"] as? NSColor { state.accent = Color(nsColor: color) }
        if let color = context["foregroundColor"] as? NSColor { state.foreground = Color(nsColor: color) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state.showPopup = nil
    }

    func makeBarView() -> NSView { NSHostingView(rootView: CounterBar(state: state)) }
    func makePopupView() -> NSView? { NSHostingView(rootView: CounterPopup(state: state)) }
}

private struct CounterBar: View {
    @ObservedObject var state: CounterState
    var body: some View {
        Button { state.showPopup?() } label: {
            HStack(spacing: 5) {
                Image(systemName: "number.circle.fill").foregroundStyle(state.accent)
                Text("\(state.count)").monospacedDigit()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(state.foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CounterPopup: View {
    @ObservedObject var state: CounterState
    var body: some View {
        VStack(spacing: 16) {
            Text(state.title).font(.headline)
            Text("\(state.count)")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            HStack {
                Button("−") { state.count -= 1 }
                Button("Reset") { state.count = 0 }
                Button("+") { state.count += 1 }
            }
            Toggle("Count every second", isOn: $state.automatic)
                .toggleStyle(.switch)
            ProgressView(value: Double(abs(state.count % 10)), total: 10)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(state.foreground)
        .tint(state.accent)
        .animation(.smooth, value: state.count)
    }
}
