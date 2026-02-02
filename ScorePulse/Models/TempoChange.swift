import Foundation

/// Type of tempo transition for gradual tempo changes
enum TempoTransition: String, Codable {
    case none
    case accelerando = "acc"
    case ritardando = "rit"
}

/// Represents a tempo change at a specific bar
struct TempoChange: Identifiable {
    let id: UUID
    let bar: Int
    let tempo: Int?  // BPM, nil if this is a transition-only bar
    let marking: String?  // Optional text like "Allegro", "Andante", etc.
    let transition: TempoTransition  // Type of transition starting at this bar
    
    init(id: UUID = UUID(), bar: Int, tempo: Int?, marking: String? = nil, transition: TempoTransition = .none) {
        self.id = id
        self.bar = bar
        self.tempo = tempo
        self.marking = marking
        self.transition = transition
    }
}

extension TempoChange: Codable {
    enum CodingKeys: String, CodingKey {
        case id, bar, tempo, marking, transition
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        bar = try container.decode(Int.self, forKey: .bar)
        // Support both Int and Int? for backwards compatibility
        tempo = try container.decodeIfPresent(Int.self, forKey: .tempo)
        marking = try container.decodeIfPresent(String.self, forKey: .marking)
        // Default to .none if transition key is missing (backwards compatibility)
        transition = try container.decodeIfPresent(TempoTransition.self, forKey: .transition) ?? .none
    }
    
    var displayText: String {
        if let tempo = tempo {
            if let marking = marking {
                return "\(marking) (♩=\(tempo))"
            }
            return "♩=\(tempo)"
        }
        // Transition-only bar
        switch transition {
        case .accelerando:
            return "accel."
        case .ritardando:
            return "rit."
        case .none:
            return ""
        }
    }
}
