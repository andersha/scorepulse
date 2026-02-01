import Foundation

/// Represents a bar with a time signature change
/// Only bars with time signature changes need to be stored
struct Bar: Codable, Identifiable {
    let id: UUID
    let number: Int
    let timeSignature: TimeSignature
    
    init(id: UUID = UUID(), number: Int, timeSignature: TimeSignature) {
        self.id = id
        self.number = number
        self.timeSignature = timeSignature
    }
}
