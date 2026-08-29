import SwiftUI

/// App root: a tab bar over the four main areas. Samples merges audio,
/// text, and image imports into one filterable list (see SamplesView).
struct HomeView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeSummaryView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            SamplesView()
                .tabItem { Label("Samples", systemImage: "tray.full") }
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
