import SwiftUI

/// App root: a tab bar over the four main areas. Recordings, Vocabulary,
/// and Settings are the existing screens, unchanged — Home is the only new
/// screen, and it only surfaces data those screens already persist.
struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeSummaryView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            VoiceMemoImportView()
                .tabItem { Label("Audio Samples", systemImage: "waveform") }
                .tag(1)

            NavigationStack {
                VocabularyListView()
            }
            .tabItem { Label("Vocabulary", systemImage: "text.book.closed") }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(3)
        }
        .tint(AppTheme.coral)
    }
}

#Preview {
    HomeView()
}
