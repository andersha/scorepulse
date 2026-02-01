import Foundation

/// Represents a musical time signature
struct TimeSignature: Codable, Equatable, Hashable {
    let beatsPerBar: Int
    let beatUnit: Int  // 2 = half note, 4 = quarter note, 8 = eighth note
    let accentPattern: [Int]?  // Optional: grouping pattern (e.g., [2, 3] for 5/8 = 2+3)
    
    init(beatsPerBar: Int, beatUnit: Int, accentPattern: [Int]? = nil) {
        self.beatsPerBar = beatsPerBar
        self.beatUnit = beatUnit
        self.accentPattern = accentPattern
    }
    
    /// Initialize from string notation (e.g. "3/4", "4/4", "6/8")
    init?(string: String) {
        let parts = string.split(separator: "/")
        guard parts.count == 2,
              let beats = Int(parts[0]),
              let unit = Int(parts[1]) else {
            return nil
        }
        self.beatsPerBar = beats
        self.beatUnit = unit
        self.accentPattern = nil
    }
    
    /// Check if this is a compound time signature (3/8, 6/8, 9/8, 12/8)
    /// In compound time, the beat is a dotted note, not the base unit
    var isCompound: Bool {
        return beatUnit == 8 && beatsPerBar % 3 == 0
    }
    
    /// Check if this is a /16 time signature (requires accent pattern)
    var isSixteenthBased: Bool {
        return beatUnit == 16
    }
    
    /// Check if this has an explicit accent pattern (5/8, 7/8, etc.)
    var hasAccentPattern: Bool {
        return accentPattern != nil && !accentPattern!.isEmpty
    }
    
    /// Generate default accent pattern for /8 time signatures
    /// - Divisible by 3: triplet groupings (3/8→[3], 6/8→[3,3], 9/8→[3,3,3])
    /// - Not divisible by 3: groups of 2, with final group being 2 or 3 (5/8→[2,3], 7/8→[2,2,3], 10/8→[2,2,2,2,2])
    var defaultAccentPattern: [Int]? {
        guard beatUnit == 8 else { return nil }
        
        if beatsPerBar % 3 == 0 {
            // Compound: all triplets
            let groupCount = beatsPerBar / 3
            return Array(repeating: 3, count: groupCount)
        } else {
            // Irregular: groups of 2, last group is 2 or 3 depending on odd/even
            var pattern: [Int] = []
            var remaining = beatsPerBar
            while remaining > 0 {
                if remaining == 3 || remaining == 2 {
                    pattern.append(remaining)
                    remaining = 0
                } else {
                    pattern.append(2)
                    remaining -= 2
                }
            }
            return pattern
        }
    }
    
    /// Get the effective accent pattern (explicit or default for /8 meters)
    /// For /16 meters, explicit pattern is required
    var effectiveAccentPattern: [Int]? {
        if beatUnit == 16 {
            return accentPattern  // /16 requires explicit pattern
        }
        return accentPattern ?? defaultAccentPattern
    }
    
    /// Check if this time signature has groupings (either explicit or default for /8, or explicit for /16)
    var hasGroupings: Bool {
        return effectiveAccentPattern != nil
    }
    
    /// Get the actual number of beats felt in the bar
    /// For 6/8, this returns 2 (two dotted quarter beats)
    /// For 5/8 with [2,3], this returns 2 (two groups)
    /// For 4/4, this returns 4 (four quarter beats)
    var actualBeatsPerBar: Int {
        if let pattern = effectiveAccentPattern {
            return pattern.count  // Number of groups
        }
        return beatsPerBar
    }
    
    /// Get the accent positions for eighth note subdivision
    /// Returns indices where accents should occur
    /// For 5/8 [2,3]: returns [0, 2] (accent on 1st and 3rd eighth note)
    /// For 7/8 [2,2,3]: returns [0, 2, 4]
    func accentPositions() -> [Int] {
        if let pattern = effectiveAccentPattern {
            var positions: [Int] = [0]  // Always accent the first
            var currentPosition = 0
            for groupSize in pattern.dropLast() {  // Don't add position after last group
                currentPosition += groupSize
                positions.append(currentPosition)
            }
            return positions
        }
        return [0]  // Default: only accent first beat
    }
    
    
    /// String representation (e.g. "3/4")
    var displayString: String {
        "\(beatsPerBar)/\(beatUnit)"
    }
    
    /// Common time signatures
    static let fourFour = TimeSignature(beatsPerBar: 4, beatUnit: 4)
    static let threeFour = TimeSignature(beatsPerBar: 3, beatUnit: 4)
    static let twoFour = TimeSignature(beatsPerBar: 2, beatUnit: 4)
    static let fiveFour = TimeSignature(beatsPerBar: 5, beatUnit: 4)
    static let sixEight = TimeSignature(beatsPerBar: 6, beatUnit: 8)
    static let nineEight = TimeSignature(beatsPerBar: 9, beatUnit: 8)
    static let twelveEight = TimeSignature(beatsPerBar: 12, beatUnit: 8)
    static let fiveEight = TimeSignature(beatsPerBar: 5, beatUnit: 8, accentPattern: [2, 3])  // 2+3
    static let sevenEight = TimeSignature(beatsPerBar: 7, beatUnit: 8, accentPattern: [2, 2, 3])  // 2+2+3
    
    static let common: [TimeSignature] = [
        .fourFour,
        .threeFour,
        .twoFour,
        .sixEight,
        .fiveFour,
        .fiveEight,
        .sevenEight,
        .nineEight,
        .twelveEight
    ]
}

// Custom Codable to support string format and pattern in JSON
extension TimeSignature {
    enum CodingKeys: String, CodingKey {
        case timeSignature
        case accentPattern
    }
    
    init(from decoder: Decoder) throws {
        // Try to decode as object with pattern
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let string = try container.decode(String.self, forKey: .timeSignature)
            let pattern = try container.decodeIfPresent([Int].self, forKey: .accentPattern)
            
            guard let ts = TimeSignature(string: string) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .timeSignature,
                    in: container,
                    debugDescription: "Invalid time signature format: \(string)"
                )
            }
            self.init(beatsPerBar: ts.beatsPerBar, beatUnit: ts.beatUnit, accentPattern: pattern)
        } else {
            // Fallback to simple string format
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let timeSignature = TimeSignature(string: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid time signature format: \(string)"
                )
            }
            self = timeSignature
        }
    }
    
    func encode(to encoder: Encoder) throws {
        if let pattern = accentPattern {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(displayString, forKey: .timeSignature)
            try container.encode(pattern, forKey: .accentPattern)
        } else {
            var container = encoder.singleValueContainer()
            try container.encode(displayString)
        }
    }
}
