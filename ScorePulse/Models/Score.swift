import Foundation

/// Represents a complete musical score
struct Score: Codable, Identifiable {
    let id: UUID
    let title: String
    let composer: String
    let defaultTempo: Int
    let tempoChanges: [TempoChange]
    let rehearsalMarks: [RehearsalMark]
    let bars: [Bar]  // Only stores bars with time signature changes
    let totalBars: Int
    
    init(id: UUID = UUID(), title: String, composer: String, defaultTempo: Int,
         tempoChanges: [TempoChange] = [], rehearsalMarks: [RehearsalMark] = [],
         bars: [Bar], totalBars: Int) {
        self.id = id
        self.title = title
        self.composer = composer
        self.defaultTempo = defaultTempo
        self.tempoChanges = tempoChanges.sorted { $0.bar < $1.bar }
        self.rehearsalMarks = rehearsalMarks.sorted { $0.bar < $1.bar }
        self.bars = bars.sorted { $0.number < $1.number }
        self.totalBars = totalBars
    }
    
    /// Get the time signature for a specific bar number
    func timeSignature(at barNumber: Int) -> TimeSignature {
        // Find the most recent bar with a time signature at or before this bar
        let relevantBars = bars.filter { $0.number <= barNumber }
        if let mostRecent = relevantBars.last {
            return mostRecent.timeSignature
        }
        // Default to 4/4 if no time signature found
        return .fourFour
    }
    
    /// Get the tempo for a specific bar number
    func tempo(at barNumber: Int) -> Int {
        // Find the most recent tempo change at or before this bar
        let relevantChanges = tempoChanges.filter { $0.bar <= barNumber }
        if let mostRecent = relevantChanges.last {
            return mostRecent.tempo
        }
        return defaultTempo
    }
    
    /// Get the tempo marking for a specific bar number
    func tempoMarking(at barNumber: Int) -> String? {
        let relevantChanges = tempoChanges.filter { $0.bar <= barNumber }
        return relevantChanges.last?.marking
    }
    
    /// Get rehearsal mark at a specific bar, if any
    func rehearsalMark(at barNumber: Int) -> RehearsalMark? {
        rehearsalMarks.first { $0.bar == barNumber }
    }
    
    /// Get the next rehearsal mark after a given bar
    func nextRehearsalMark(after barNumber: Int) -> RehearsalMark? {
        rehearsalMarks.first { $0.bar > barNumber }
    }
    
    /// Get the previous rehearsal mark before a given bar
    func previousRehearsalMark(before barNumber: Int) -> RehearsalMark? {
        rehearsalMarks.reversed().first { $0.bar < barNumber }
    }
}

/// Container for loading multiple scores from JSON
struct ScoreCollection: Codable {
    let scores: [Score]
}
