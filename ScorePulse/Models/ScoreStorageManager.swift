import Foundation

/// Manages persistent storage of user-imported scores
class ScoreStorageManager {
    static let shared = ScoreStorageManager()
    
    private let fileManager = FileManager.default
    private let scoresDirectoryName = "Scores"
    
    /// Directory where user scores are stored
    private var scoresDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(scoresDirectoryName)
    }
    
    private init() {
        createScoresDirectoryIfNeeded()
    }
    
    /// Create the Scores directory if it doesn't exist
    private func createScoresDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: scoresDirectory.path) {
            try? fileManager.createDirectory(at: scoresDirectory, withIntermediateDirectories: true)
        }
    }
    
    /// Save a score to persistent storage
    func saveScore(_ score: Score) throws {
        let fileURL = scoresDirectory.appendingPathComponent("\(score.id.uuidString).scorepulse")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(score)
        try data.write(to: fileURL)
    }
    
    /// Load all user-imported scores from storage
    func loadAllScores() -> [Score] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: scoresDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        let scores = fileURLs.compactMap { url -> Score? in
            guard url.pathExtension == "scorepulse" else { return nil }
            return try? loadScore(from: url)
        }
        
        return scores
    }
    
    /// Load a score from a specific URL
    func loadScore(from url: URL) throws -> Score {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Score.self, from: data)
    }
    
    /// Delete a score from storage
    func deleteScore(_ score: Score) throws {
        let fileURL = scoresDirectory.appendingPathComponent("\(score.id.uuidString).scorepulse")
        try fileManager.removeItem(at: fileURL)
    }
    
    /// Check if a score already exists in storage
    func scoreExists(_ score: Score) -> Bool {
        let fileURL = scoresDirectory.appendingPathComponent("\(score.id.uuidString).scorepulse")
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Import a score from an external URL (Files app, Open-In, etc.)
    func importScore(from sourceURL: URL) throws -> Score {
        // Load and validate the score
        let score = try loadScore(from: sourceURL)
        
        // Save to our storage
        try saveScore(score)
        
        return score
    }
}
