//
//  Zone.swift
//  MotoresRD
//

import Foundation
import CoreLocation
import MapKit

struct Zone: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let displayName: String          // Spanish name shown in UI
    let polygon: [CLLocationCoordinate2D]

    // Firestore-friendly encoding
    enum CodingKeys: String, CodingKey {
        case id, name, displayName, coordinates
    }

    init(id: String, name: String, displayName: String, polygon: [CLLocationCoordinate2D]) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.polygon = polygon
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        displayName = try c.decode(String.self, forKey: .displayName)
        let coords = try c.decode([[Double]].self, forKey: .coordinates)
        polygon = coords.compactMap {
            guard $0.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1])
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(displayName, forKey: .displayName)
        let coords = polygon.map { [$0.latitude, $0.longitude] }
        try c.encode(coords, forKey: .coordinates)
    }

    static func == (lhs: Zone, rhs: Zone) -> Bool { lhs.id == rhs.id }

    /// Returns true if the given coordinate falls inside this zone's polygon.
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard polygon.count >= 3 else { return false }
        let mkPoly = MKPolygon(coordinates: polygon, count: polygon.count)
        let renderer = MKPolygonRenderer(polygon: mkPoly)
        let point = renderer.point(for: MKMapPoint(coordinate))
        return renderer.path?.contains(point) ?? false
    }
}

// MARK: - Pricing pair

struct ZonePricePair: Identifiable, Codable {
    let id: String          // "\(fromZoneId)_\(toZoneId)"
    let fromZoneId: String
    let toZoneId: String
    let priceDOP: Int       // Dominican Pesos

    static func makeId(from: String, to: String) -> String {
        // Always store with lexicographic order so A→B == B→A
        [from, to].sorted().joined(separator: "_")
    }
}
