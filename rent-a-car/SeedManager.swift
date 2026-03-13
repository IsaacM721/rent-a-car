//
//  SeedManager.swift
//  rent-a-car
//

import Foundation
import SwiftData
import UIKit

// MARK: - Seed File Format

struct CarSeed: Codable {
    let id: String
    let name: String
    let type: String
    let priceLevel: String
    let neighborhood: String
    let isAvailable: Bool
    let availableFrom: String
    let details: String
    let schedule: [DaySchedule]
    let address: String
    let latitude: Double
    let longitude: Double
    let logoColorR: Double
    let logoColorG: Double
    let logoColorB: Double
    let logoInitials: String
    let images: [String] // base64-encoded JPEG strings
}

struct SeedFile: Codable {
    let version: Int
    let exportedAt: Date
    let vehicles: [CarSeed]
}

// MARK: - SeedManager

enum SeedManager {

    // MARK: Export

    static func export(cars: [CarModel]) throws -> URL {
        let seeds = cars.map { car -> CarSeed in
            let images = car.imagePaths.compactMap { path -> String? in
                let url = imageDirectory.appendingPathComponent(path)
                guard let data = try? Data(contentsOf: url) else { return nil }
                return data.base64EncodedString()
            }
            return CarSeed(
                id: car.id.uuidString,
                name: car.name,
                type: car.type,
                priceLevel: car.priceLevel,
                neighborhood: car.neighborhood,
                isAvailable: car.isAvailable,
                availableFrom: car.availableFrom,
                details: car.details,
                schedule: car.schedule,
                address: car.address,
                latitude: car.latitude,
                longitude: car.longitude,
                logoColorR: car.logoColorR,
                logoColorG: car.logoColorG,
                logoColorB: car.logoColorB,
                logoInitials: car.logoInitials,
                images: images
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let file = SeedFile(version: 1, exportedAt: Date(), vehicles: seeds)
        let data = try encoder.encode(file)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vehicles_seed.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Import

    static func importSeed(from url: URL, context: ModelContext) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(SeedFile.self, from: data)

        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)

        for seed in file.vehicles {
            // Save images to disk
            var paths: [String] = []
            for (index, base64) in seed.images.enumerated() {
                guard let imageData = Data(base64Encoded: base64) else { continue }
                let filename = "\(seed.id)_\(index).jpg"
                let dest = imageDirectory.appendingPathComponent(filename)
                try imageData.write(to: dest, options: .atomic)
                paths.append(filename)
            }

            let car = CarModel(
                id: UUID(uuidString: seed.id) ?? UUID(),
                name: seed.name,
                type: seed.type,
                priceLevel: seed.priceLevel,
                neighborhood: seed.neighborhood,
                isAvailable: seed.isAvailable,
                availableFrom: seed.availableFrom,
                details: seed.details,
                schedule: seed.schedule,
                address: seed.address,
                latitude: seed.latitude,
                longitude: seed.longitude,
                logoColorR: seed.logoColorR,
                logoColorG: seed.logoColorG,
                logoColorB: seed.logoColorB,
                logoInitials: seed.logoInitials,
                imagePaths: paths
            )
            context.insert(car)
        }
    }

    // MARK: Image Storage

    static var imageDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("vehicle_images", isDirectory: true)
    }

    static func saveImage(_ image: UIImage, forCar id: UUID, index: Int) throws -> String {
        try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        let filename = "\(id.uuidString)_\(index).jpg"
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: imageDirectory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    static func loadImage(path: String) -> UIImage? {
        UIImage(contentsOfFile: imageDirectory.appendingPathComponent(path).path)
    }

    static func deleteImage(path: String) {
        try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(path))
    }
}
