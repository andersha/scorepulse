import Foundation

/// Represents a rehearsal mark at a specific bar
struct RehearsalMark: Codable, Identifiable {
    let id: UUID
    let name: String  // e.g. "A", "B", "1", "2", etc.
    let bar: Int
    
    init(id: UUID = UUID(), name: String, bar: Int) {
        self.id = id
        self.name = name
        self.bar = bar
    }
    
    var displayText: String {
        "[\(name)]"
    }
}
