import Foundation

/// Represents a tempo change at a specific bar
struct TempoChange: Codable, Identifiable {
    let id: UUID
    let bar: Int
    let tempo: Int  // BPM
    let marking: String?  // Optional text like "Allegro", "Andante", etc.
    
    init(id: UUID = UUID(), bar: Int, tempo: Int, marking: String? = nil) {
        self.id = id
        self.bar = bar
        self.tempo = tempo
        self.marking = marking
    }
    
    var displayText: String {
        if let marking = marking {
            return "\(marking) (♩=\(tempo))"
        }
        return "♩=\(tempo)"
    }
}
