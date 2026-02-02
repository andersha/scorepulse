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
    
    /// Get the base tempo for a specific bar number (ignores transitions)
    func tempo(at barNumber: Int) -> Int {
        // Find the most recent tempo change with an actual tempo at or before this bar
        let relevantChanges = tempoChanges.filter { $0.bar <= barNumber && $0.tempo != nil }
        if let mostRecent = relevantChanges.last, let tempo = mostRecent.tempo {
            return tempo
        }
        return defaultTempo
    }
    
    /// Get the tempo for a specific bar and beat position, accounting for gradual transitions
    /// - Parameters:
    ///   - barNumber: The bar number
    ///   - beatProgress: Progress through the bar (0.0 to 1.0), where 0.0 is start and 1.0 is end
    /// - Returns: The interpolated tempo at this position
    func tempo(at barNumber: Int, beatProgress: Double) -> Int {
        // Check if we're in a transition range (includes both single and multi-bar transitions)
        if let (startBar, endBar, startTempo, endTempo) = findTransitionRange(containing: barNumber) {
            // Calculate overall progress through the transition range
            let totalBars = endBar - startBar
            let barsCompleted = barNumber - startBar
            let overallProgress = (Double(barsCompleted) + beatProgress) / Double(totalBars)
            
            let interpolated = Double(startTempo) + (Double(endTempo - startTempo) * overallProgress)
            return Int(interpolated)
        }
        
        // No transition, return base tempo
        return tempo(at: barNumber)
    }
    
    /// Find the tempo before a transition starts
    private func tempoBeforeTransition(at barNumber: Int) -> Int {
        // Look for the most recent bar with an actual tempo before this bar
        let previousTempoChanges = tempoChanges.filter { $0.bar < barNumber && $0.tempo != nil }
        if let previous = previousTempoChanges.last, let tempo = previous.tempo {
            return tempo
        }
        return defaultTempo
    }
    
    /// Find if a bar is within a transition range (one or more acc/rit bars leading to a tempo)
    /// - Returns: (startBar, endBar, startTempo, endTempo) or nil if not in a transition
    private func findTransitionRange(containing barNumber: Int) -> (Int, Int, Int, Int)? {
        // Find all transition markers
        let transitionMarkers = tempoChanges.filter { $0.transition != .none }
        
        for marker in transitionMarkers {
            // Find the end of this transition (next bar with a tempo)
            guard let endChange = tempoChanges.first(where: { $0.bar > marker.bar && $0.tempo != nil }),
                  let endTempo = endChange.tempo else {
                continue
            }
            
            let startBar = marker.bar
            let endBar = endChange.bar
            
            // Check if barNumber is within this range
            if barNumber >= startBar && barNumber < endBar {
                let startTempo = tempoBeforeTransition(at: startBar)
                return (startBar, endBar, startTempo, endTempo)
            }
        }
        
        return nil
    }
    
    /// Check if a bar is in a tempo transition
    func isInTransition(at barNumber: Int) -> Bool {
        // Direct transition marker on this bar
        if tempoChanges.contains(where: { $0.bar == barNumber && $0.transition != .none }) {
            return true
        }
        // Part of a multi-bar transition range
        return findTransitionRange(containing: barNumber) != nil
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
