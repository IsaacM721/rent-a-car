//
//  SantoDomingoZones.swift
//  MotoresRD
//
//  Santo Domingo zone definitions + initial pricing matrix.
//  Polygons are approximate — tighten with real GeoJSON before launch.
//

import CoreLocation

enum SantoDomingoZones {

    // MARK: - Zone definitions

    static let all: [Zone] = [
        Zone(
            id: "zona_colonial",
            name: "zona_colonial",
            displayName: "Zona Colonial",
            polygon: [
                CLLocationCoordinate2D(latitude: 18.4820, longitude: -69.9040),
                CLLocationCoordinate2D(latitude: 18.4820, longitude: -69.8820),
                CLLocationCoordinate2D(latitude: 18.4720, longitude: -69.8820),
                CLLocationCoordinate2D(latitude: 18.4720, longitude: -69.9040)
            ]
        ),
        Zone(
            id: "gazcue",
            name: "gazcue",
            displayName: "Gazcue",
            polygon: [
                CLLocationCoordinate2D(latitude: 18.4780, longitude: -69.9120),
                CLLocationCoordinate2D(latitude: 18.4780, longitude: -69.9000),
                CLLocationCoordinate2D(latitude: 18.4680, longitude: -69.9000),
                CLLocationCoordinate2D(latitude: 18.4680, longitude: -69.9120)
            ]
        ),
        Zone(
            id: "piantini_naco",
            name: "piantini_naco",
            displayName: "Piantini / Naco",
            polygon: [
                CLLocationCoordinate2D(latitude: 18.4800, longitude: -69.9440),
                CLLocationCoordinate2D(latitude: 18.4800, longitude: -69.9160),
                CLLocationCoordinate2D(latitude: 18.4620, longitude: -69.9160),
                CLLocationCoordinate2D(latitude: 18.4620, longitude: -69.9440)
            ]
        ),
        Zone(
            id: "bella_vista",
            name: "bella_vista",
            displayName: "Bella Vista / Serralles",
            polygon: [
                CLLocationCoordinate2D(latitude: 18.4680, longitude: -69.9400),
                CLLocationCoordinate2D(latitude: 18.4680, longitude: -69.9160),
                CLLocationCoordinate2D(latitude: 18.4500, longitude: -69.9160),
                CLLocationCoordinate2D(latitude: 18.4500, longitude: -69.9400)
            ]
        ),
        Zone(
            id: "los_prados",
            name: "los_prados",
            displayName: "Los Prados / Evaristo Morales",
            polygon: [
                CLLocationCoordinate2D(latitude: 18.4980, longitude: -69.9600),
                CLLocationCoordinate2D(latitude: 18.4980, longitude: -69.9340),
                CLLocationCoordinate2D(latitude: 18.4800, longitude: -69.9340),
                CLLocationCoordinate2D(latitude: 18.4800, longitude: -69.9600)
            ]
        ),
        Zone(
            id: "arroyo_hondo",
            name: "arroyo_hondo",
            displayName: "Arroyo Hondo",
            polygon: [
                CLLocationCoordinate2D(latitude: 18.5100, longitude: -69.9780),
                CLLocationCoordinate2D(latitude: 18.5100, longitude: -69.9520),
                CLLocationCoordinate2D(latitude: 18.4920, longitude: -69.9520),
                CLLocationCoordinate2D(latitude: 18.4920, longitude: -69.9780)
            ]
        ),
        Zone(
            id: "sd_norte",
            name: "sd_norte",
            displayName: "Santo Domingo Norte",
            polygon: [
                CLLocationCoordinate2D(latitude: 18.5600, longitude: -69.9600),
                CLLocationCoordinate2D(latitude: 18.5600, longitude: -69.8700),
                CLLocationCoordinate2D(latitude: 18.5020, longitude: -69.8700),
                CLLocationCoordinate2D(latitude: 18.5020, longitude: -69.9600)
            ]
        ),
        Zone(
            id: "sd_este",
            name: "sd_este",
            displayName: "Santo Domingo Este",
            polygon: [
                CLLocationCoordinate2D(latitude: 18.5020, longitude: -69.8820),
                CLLocationCoordinate2D(latitude: 18.5020, longitude: -69.8400),
                CLLocationCoordinate2D(latitude: 18.4600, longitude: -69.8400),
                CLLocationCoordinate2D(latitude: 18.4600, longitude: -69.8820)
            ]
        ),
        Zone(
            id: "sd_oeste",
            name: "sd_oeste",
            displayName: "Santo Domingo Oeste / Cristo Rey",
            polygon: [
                CLLocationCoordinate2D(latitude: 18.5100, longitude: -70.0400),
                CLLocationCoordinate2D(latitude: 18.5100, longitude: -69.9700),
                CLLocationCoordinate2D(latitude: 18.4680, longitude: -69.9700),
                CLLocationCoordinate2D(latitude: 18.4680, longitude: -70.0400)
            ]
        )
    ]

    // MARK: - Pricing matrix (RD$)
    // Same zone = RD$100. Adjacent zones = RD$150. Far = RD$200–350.

    static let prices: [ZonePricePair] = buildPrices()

    private static func buildPrices() -> [ZonePricePair] {
        // [fromZoneId, toZoneId, priceDOP]
        let matrix: [(String, String, Int)] = [
            // Same-zone rides
            ("zona_colonial",  "zona_colonial",  100),
            ("gazcue",         "gazcue",         100),
            ("piantini_naco",  "piantini_naco",  100),
            ("bella_vista",    "bella_vista",    100),
            ("los_prados",     "los_prados",     100),
            ("arroyo_hondo",   "arroyo_hondo",   100),
            ("sd_norte",       "sd_norte",       100),
            ("sd_este",        "sd_este",        100),
            ("sd_oeste",       "sd_oeste",       100),

            // Adjacent / short cross-zone
            ("zona_colonial",  "gazcue",         150),
            ("zona_colonial",  "sd_este",        150),
            ("gazcue",         "piantini_naco",  150),
            ("gazcue",         "bella_vista",    150),
            ("piantini_naco",  "bella_vista",    150),
            ("piantini_naco",  "los_prados",     150),
            ("los_prados",     "arroyo_hondo",   150),

            // Medium distance
            ("zona_colonial",  "piantini_naco",  200),
            ("zona_colonial",  "bella_vista",    200),
            ("gazcue",         "los_prados",     200),
            ("gazcue",         "arroyo_hondo",   200),
            ("piantini_naco",  "arroyo_hondo",   200),
            ("bella_vista",    "los_prados",     200),
            ("sd_norte",       "piantini_naco",  200),
            ("sd_norte",       "los_prados",     200),
            ("sd_este",        "gazcue",         200),
            ("sd_este",        "piantini_naco",  200),
            ("sd_oeste",       "piantini_naco",  200),
            ("sd_oeste",       "bella_vista",    200),

            // Far
            ("zona_colonial",  "arroyo_hondo",   250),
            ("zona_colonial",  "los_prados",     250),
            ("zona_colonial",  "sd_norte",       250),
            ("zona_colonial",  "sd_oeste",       250),
            ("gazcue",         "sd_norte",       250),
            ("gazcue",         "sd_oeste",       250),
            ("gazcue",         "sd_este",        250),
            ("bella_vista",    "arroyo_hondo",   250),
            ("sd_este",        "bella_vista",    250),
            ("sd_este",        "los_prados",     250),
            ("sd_norte",       "arroyo_hondo",   250),
            ("sd_norte",       "sd_este",        250),
            ("sd_oeste",       "arroyo_hondo",   250),
            ("sd_oeste",       "los_prados",     250),

            // Very far / across city
            ("zona_colonial",  "sd_oeste",       300),
            ("sd_este",        "arroyo_hondo",   300),
            ("sd_este",        "sd_oeste",       300),
            ("sd_este",        "sd_norte",       300),
            ("sd_norte",       "sd_oeste",       300),
            ("bella_vista",    "sd_norte",       300),
            ("bella_vista",    "sd_este",        300),
            ("arroyo_hondo",   "sd_este",        350),
            ("arroyo_hondo",   "sd_norte",       350),
            ("sd_norte",       "arroyo_hondo",   350),
        ]

        return matrix.map { (from, to, price) in
            ZonePricePair(
                id: ZonePricePair.makeId(from: from, to: to),
                fromZoneId: from,
                toZoneId: to,
                priceDOP: price
            )
        }
    }
}
