import SwiftUI

@main
struct GlanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit Glance") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}
