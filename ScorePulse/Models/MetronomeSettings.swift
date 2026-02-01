import Foundation
import SwiftUI

/// Subdivision mode for metronome clicks
enum SubdivisionMode: String, CaseIterable, Identifiable {
    case quarter = "Quarter Notes"
    case eighth = "Eighth Notes"
    
    var id: String { rawValue }
    
    var displaySymbol: String {
        switch self {
        case .quarter: return "♩"
        case .eighth: return "♪"
        }
    }
}

/// App settings and state management
class MetronomeSettings: ObservableObject {
    // Simple metronome settings
    @Published var bpm: Int = 120
    @Published var timeSignature: TimeSignature = .fourFour
    @Published var subdivision: SubdivisionMode = .quarter
    
    // Score playback settings
    @Published var selectedScore: Score?
    @Published var currentBar: Int = 1
    @Published var tempoMultiplier: Double = 1.0  // 0.5 to 1.5 for practice
    @Published var rehearsalMode: Bool = false
    @Published var rehearsalStartBar: Int = 1
    
    // Available scores
    @Published var availableScores: [Score] = []
    @Published var bundledScores: [Score] = []
    @Published var userScores: [Score] = []
    
    private let storageManager = ScoreStorageManager.shared
    
    init() {
        loadAllScores()
    }
    
    /// Load all scores from both bundled and user storage
    func loadAllScores() {
        loadBundledScores()
        loadUserScores()
        availableScores = bundledScores + userScores
    }
    
    /// Load scores from bundled JSON file
    private func loadBundledScores() {
        guard let url = Bundle.main.url(forResource: "bundled-scores", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load bundled-scores.json")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let collection = try decoder.decode(ScoreCollection.self, from: data)
            bundledScores = collection.scores
        } catch {
            print("Failed to decode scores: \(error)")
        }
    }
    
    /// Load user-imported scores from storage
    private func loadUserScores() {
        userScores = storageManager.loadAllScores()
    }
    
    /// Import a score from a URL
    func importScore(from url: URL) throws {
        let score = try storageManager.importScore(from: url)
        
        // Check if score already exists in user scores
        if !userScores.contains(where: { $0.id == score.id }) {
            userScores.append(score)
            availableScores = bundledScores + userScores
        }
    }
    
    /// Delete a user score
    func deleteUserScore(_ score: Score) throws {
        // Only allow deleting user scores, not bundled ones
        guard userScores.contains(where: { $0.id == score.id }) else {
            throw NSError(domain: "ScorePulse", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot delete bundled scores"])
        }
        
        try storageManager.deleteScore(score)
        userScores.removeAll { $0.id == score.id }
        availableScores = bundledScores + userScores
    }
    
    /// Check if a score is a bundled score (cannot be deleted)
    func isBundledScore(_ score: Score) -> Bool {
        bundledScores.contains { $0.id == score.id }
    }
    
    /// Get the effective tempo for the current bar (with multiplier applied)
    func effectiveTempo(for score: Score, at bar: Int) -> Int {
        let baseTempo = score.tempo(at: bar)
        return Int(Double(baseTempo) * tempoMultiplier)
    }
    
    /// Reset to rehearsal start position
    func resetToRehearsalStart() {
        if rehearsalMode {
            currentBar = rehearsalStartBar
        }
    }
}
