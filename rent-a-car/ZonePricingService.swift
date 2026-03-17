//
//  ZonePricingService.swift
//  MotoresRD
//
//  Detects which zone a coordinate falls in and looks up the price.
//  Backed by in-memory data now; swap the `zones` and `prices` properties
//  for Firestore fetches when Firebase is wired up.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class ZonePricingService: ObservableObject {

    static let shared = ZonePricingService()

    // Swap these for Firestore-fetched data later
    @Published private(set) var zones: [Zone] = SantoDomingoZones.all
    @Published private(set) var prices: [ZonePricePair] = SantoDomingoZones.prices
    @Published private(set) var isLoaded = true   // flip to false when fetching from Firestore

    private var priceIndex: [String: Int] = [:]   // id → priceDOP

    private init() {
        buildIndex()
    }

    // MARK: - Public API

    /// Returns the Zone that contains the given coordinate, or nil if outside all zones.
    func zone(for coordinate: CLLocationCoordinate2D) -> Zone? {
        zones.first { $0.contains(coordinate) }
    }

    /// Returns the fixed price (RD$) for a ride between two zones.
    /// Falls back to the default rate if the pair isn't in the matrix.
    func price(from: Zone, to: Zone) -> Int {
        let key = ZonePricePair.makeId(from: from.id, to: to.id)
        return priceIndex[key] ?? defaultPrice(from: from, to: to)
    }

    /// Formatted price string, e.g. "RD$200"
    func formattedPrice(from: Zone, to: Zone) -> String {
        "RD$\(price(from: from, to: to))"
    }

    /// Returns both zones and price for two coordinates in one call.
    func quote(pickup: CLLocationCoordinate2D,
               dropoff: CLLocationCoordinate2D) -> RideQuote? {
        guard
            let fromZone = zone(for: pickup),
            let toZone = zone(for: dropoff)
        else { return nil }

        return RideQuote(
            fromZone: fromZone,
            toZone: toZone,
            priceDOP: price(from: fromZone, to: toZone)
        )
    }

    // MARK: - Private

    private func buildIndex() {
        priceIndex = Dictionary(
            uniqueKeysWithValues: prices.map { ($0.id, $0.priceDOP) }
        )
    }

    /// Fallback: estimate price by straight-line distance between zone polygon centroids.
    private func defaultPrice(from: Zone, to: Zone) -> Int {
        let d = centroid(of: from.polygon).distance(to: centroid(of: to.polygon))
        switch d {
        case ..<2_000:  return 100
        case ..<5_000:  return 150
        case ..<10_000: return 200
        case ..<15_000: return 250
        default:        return 300
        }
    }

    private func centroid(of coords: [CLLocationCoordinate2D]) -> CLLocation {
        let lat = coords.map(\.latitude).reduce(0, +) / Double(coords.count)
        let lng = coords.map(\.longitude).reduce(0, +) / Double(coords.count)
        return CLLocation(latitude: lat, longitude: lng)
    }
}

// MARK: - CLLocation helper

private extension CLLocation {
    func distance(to other: CLLocation) -> Double {
        self.distance(from: other)
    }
}

// MARK: - RideQuote

struct RideQuote {
    let fromZone: Zone
    let toZone: Zone
    let priceDOP: Int

    var formattedPrice: String { "RD$\(priceDOP)" }

    /// Your 5% cut
    var platformCutDOP: Int { Int((Double(priceDOP) * 0.05).rounded()) }

    /// Driver's 95%
    var driverEarningsDOP: Int { priceDOP - platformCutDOP }
}
