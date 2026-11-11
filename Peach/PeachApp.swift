import SwiftUI
import SwiftData

@main
struct PeachApp: App {
    @State private var manager = DownloadManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(manager)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .statusBarHidden(false)
        }
        .modelContainer(for: DownloadRecord.self)
    }
}

struct RootView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            Tab("İndir", systemImage: "arrow.down.circle.fill", value: 0) {
                HomeView(openSettings: { tab = 2 })
            }
            Tab("Kitaplık", systemImage: "square.stack.fill", value: 1) {
                LibraryView()
            }
            Tab("Ayarlar", systemImage: "gearshape.fill", value: 2) {
                SettingsView()
            }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}
