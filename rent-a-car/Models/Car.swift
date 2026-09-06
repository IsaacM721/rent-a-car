import CoreLocation
import FirebaseFirestore
import Foundation
import SwiftUI

struct Car: Identifiable, Codable, Hashable {
    struct Logo: Codable, Hashable {
        var r: Double
        var g: Double
        var b: Double
        var initials: String
    }

    @DocumentID var docId: String?
    var id: String { docId ?? "" }

    var name: String
    var type: String
    var priceLevel: String
    var neighborhood: String
    var isAvailable: Bool
    var availableFrom: String
    var details: String
    var address: String
    var latitude: Double
    var longitude: Double
    var photoURLs: [String]
    var logo: Logo
    var isActive: Bool
    var ownerId: String = ""

    /// Optional code two dealers agree on when they're listing the exact same physical
    /// vehicle (e.g. a shared fleet car, or one changing hands). When set, this car's
    /// live "in use" status is looked up under this key instead of its own `id`, so
    /// flipping the switch on one dealer's listing is reflected on the other's too.
    var sharedVehicleCode: String = ""

    /// The key used to look up this car's live availability in `VehicleStatusStore`.
    /// Falls back to the car's own id when no shared code has been set.
    var vehicleStatusKey: String {
        let trimmed = sharedVehicleCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? id : trimmed
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var logoColor: Color {
        Color(red: logo.r, green: logo.g, blue: logo.b)
    }

    var logoInitials: String {
        let trimmed = logo.initials.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return String(trimmed.prefix(2)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}

