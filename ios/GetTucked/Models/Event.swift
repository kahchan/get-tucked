import Foundation
import SwiftData

/// A dated tag a position can carry (Plan AL9, SchemaV10). Spec §6 frames
/// events as tags with a date, not folders — a position can belong to
/// several, which is what unlocks a future "setup evolution into Tour
/// Divide" timeline. No dedicated management screen yet: LeaderboardView's
/// inline add is the only writer, and its event filter is the only reader.
@Model
final class Event {
    var id: UUID
    var name: String
    var date: Date
    var notes: String?

    var positions: [Position]

    init(name: String, date: Date = Date(), notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.notes = notes
        self.positions = []
    }
}
