import CoreLocation
import FirebaseFirestoreSwift
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

