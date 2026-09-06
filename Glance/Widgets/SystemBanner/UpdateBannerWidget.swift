import SwiftUI

struct UpdateBannerWidget: View {
    @StateObject private var updater = AppUpdater()

    var body: some View {
        if updater.updateAvailable {
            Button(action: handleUpdate) {
                Text("Update")
                    .fontWeight(.semibold)
            }
            .buttonStyle(BannerButtonStyle(color: Color(nsColor: .controlAccentColor)))
        }
    }

    /// Opens the GitHub releases page so the user can download via Sparkle or manually.
    private func handleUpdate() {
        NSWorkspace.shared.open(AppUpdater.releasesURL)
    }
}

struct UpdateBannerWidget_Previews: PreviewProvider {
    static var previews: some View {
        UpdateBannerWidget()
            .frame(width: 200, height: 100)
            .background(Color.black)
    }
}
