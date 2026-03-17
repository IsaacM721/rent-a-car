//
//  CarModel.swift
//  rent-a-car
//

import Foundation
import SwiftData
import CoreLocation
import SwiftUI

@Model
class CarModel {
    var id: UUID
    var name: String
    var type: String
    var priceLevel: String
    var neighborhood: String
    var isAvailable: Bool
    var availableFrom: String
    var details: String
    var scheduleData: Data
    var address: String
    var latitude: Double
    var longitude: Double
    var logoColorR: Double
    var logoColorG: Double
    var logoColorB: Double
    var logoInitials: String
    var imagePaths: [String]

    init(
        id: UUID = UUID(),
        name: String,
        type: String,
        priceLevel: String,
        neighborhood: String,
        isAvailable: Bool = true,
        availableFrom: String = "9:00 AM",
        details: String = "",
        schedule: [DaySchedule] = DaySchedule.defaultWeek,
        address: String = "",
        latitude: Double = 18.4861,
        longitude: Double = -69.9312,
        logoColorR: Double = 0.2,
        logoColorG: Double = 0.2,
        logoColorB: Double = 0.8,
        logoInitials: String = "",
        imagePaths: [String] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.priceLevel = priceLevel
        self.neighborhood = neighborhood
        self.isAvailable = isAvailable
        self.availableFrom = availableFrom
        self.details = details
        self.scheduleData = (try? JSONEncoder().encode(schedule)) ?? Data()
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.logoColorR = logoColorR
        self.logoColorG = logoColorG
        self.logoColorB = logoColorB
        self.logoInitials = logoInitials
        self.imagePaths = imagePaths
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var logoColor: Color {
        Color(red: logoColorR, green: logoColorG, blue: logoColorB)
    }

    var schedule: [DaySchedule] {
        get {
            (try? JSONDecoder().decode([DaySchedule].self, from: scheduleData)) ?? DaySchedule.defaultWeek
        }
        set {
            scheduleData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}

// Note: `CarModel` is legacy SwiftData/demo storage.
// Production inventory uses `Car` (Firestore-backed) in `Models/Car.swift`.
