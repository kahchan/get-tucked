import Foundation
import SwiftData

enum BikeType: String, Codable, CaseIterable {
    case road = "ROAD"
    case gravel = "GRAVEL"
    case mtb = "MTB"

    var displayName: String { rawValue }
}

@Model
final class Bike {
    var id: UUID
    var nickname: String
    var handlebarWidthMm: Double
    var bikeType: BikeType
    var wheelbaseCm: Double?
    var notes: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Position.bike)
    var positions: [Position]

    init(nickname: String, handlebarWidthMm: Double, bikeType: BikeType = .road) {
        self.id = UUID()
        self.nickname = nickname
        self.handlebarWidthMm = handlebarWidthMm
        self.bikeType = bikeType
        self.createdAt = Date()
        self.positions = []
    }

    var handlebarWidthCm: Double { handlebarWidthMm / 10.0 }
}
