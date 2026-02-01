import SwiftUI

@main
struct ScorePulseApp: App {
    @StateObject private var settings = MetronomeSettings()
    @State private var selectedTab = 1
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                MetronomeView()
                    .tabItem {
                        Label("Metronome", systemImage: "metronome")
                    }
                    .tag(0)
                
                ScoreListView()
                    .environmentObject(settings)
                    .tabItem {
                        Label("Scores", systemImage: "music.note.list")
                    }
                    .tag(1)
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Switch to scores tab
        selectedTab = 1
        
        // Access security-scoped resource
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Import the score
        do {
            try settings.importScore(from: url)
        } catch {
            print("Failed to import score from URL: \(error.localizedDescription)")
        }
    }
}
