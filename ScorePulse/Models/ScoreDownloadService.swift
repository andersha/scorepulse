import Foundation

/// Represents a score available for download from the online archive
struct DownloadableScore: Codable, Identifiable {
    let id: UUID
    let title: String
    let composer: String
    let defaultTempo: Int
    let totalBars: Int
    let filename: String
    
    var downloadURL: URL {
        URL(string: "https://andersha.github.io/scorepulse/scores/\(filename)")!
    }
}

/// Container for the scores manifest
struct ScoresManifest: Codable {
    let scores: [DownloadableScore]
}

/// Service for downloading scores from the online archive
@MainActor
class ScoreDownloadService: ObservableObject {
    static let shared = ScoreDownloadService()
    
    private let manifestURL = URL(string: "https://andersha.github.io/scorepulse/scores/scores-manifest.json")!
    
    @Published var availableScores: [DownloadableScore] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private init() {}
    
    /// Fetch the list of available scores from the archive
    func fetchAvailableScores() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (data, _) = try await URLSession.shared.data(from: manifestURL)
            let manifest = try JSONDecoder().decode(ScoresManifest.self, from: data)
            availableScores = manifest.scores
        } catch {
            errorMessage = "Score archive not available"
            availableScores = []
        }
        
        isLoading = false
    }
    
    /// Download a specific score and save it to user storage
    func downloadScore(_ downloadableScore: DownloadableScore) async throws -> Score {
        let (data, _) = try await URLSession.shared.data(from: downloadableScore.downloadURL)
        let score = try JSONDecoder().decode(Score.self, from: data)
        
        // Save to persistent storage
        try ScoreStorageManager.shared.saveScore(score)
        
        return score
    }
}
