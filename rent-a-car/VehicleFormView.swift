//
//  VehicleFormView.swift
//  rent-a-car
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct VehicleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // If non-nil, we're editing an existing car
    var car: CarModel?

    // Fields
    @State private var name = ""
    @State private var type = "Sedan"
    @State private var priceLevel = "$$"
    @State private var neighborhood = ""
    @State private var isAvailable = true
    @State private var availableFrom = "9:00 AM"
    @State private var details = ""
    @State private var address = ""
    @State private var latitude = "18.4861"
    @State private var longitude = "-69.9312"
    @State private var logoInitials = ""
    @State private var logoColor = Color(red: 0.2, green: 0.2, blue: 0.8)
    @State private var schedule: [DaySchedule] = DaySchedule.defaultWeek

    // Images
    @State private var existingPaths: [String] = []
    @State private var newImages: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []

    let vehicleTypes = ["Sedan", "SUV", "Hatchback", "Pickup", "Van", "Convertible"]
    let priceLevels = ["$", "$$", "$$$"]

    var isEditing: Bool { car != nil }
    var title: String { isEditing ? "Edit Vehicle" : "Add Vehicle" }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name (e.g. Toyota Corolla 2024)", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(vehicleTypes, id: \.self) { Text($0) }
                    }
                    Picker("Price Level", selection: $priceLevel) {
                        ForEach(priceLevels, id: \.self) { Text($0) }
                    }
                    TextField("Neighborhood", text: $neighborhood)
                    TextField("Address", text: $address)
                }

                Section("Availability") {
                    Toggle("Available Now", isOn: $isAvailable)
                    if !isAvailable {
                        TextField("Available from (e.g. 2:00 PM)", text: $availableFrom)
                    }
                }

                Section("Description") {
                    TextEditor(text: $details)
                        .frame(minHeight: 80)
                }

                Section("Logo") {
                    HStack {
                        TextField("Initials (2 chars)", text: $logoInitials)
                            .onChange(of: logoInitials) { _, new in
                                if new.count > 2 { logoInitials = String(new.prefix(2)).uppercased() }
                                else { logoInitials = new.uppercased() }
                            }
                        Spacer()
                        ColorPicker("Color", selection: $logoColor, supportsOpacity: false)
                    }
                    if !logoInitials.isEmpty {
                        HStack {
                            Text("Preview")
                                .foregroundStyle(Color.secondary)
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(logoColor)
                                Text(logoInitials)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 44, height: 44)
                        }
                    }
                }

                Section("Location") {
                    TextField("Latitude", text: $latitude)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $longitude)
                        .keyboardType(.decimalPad)
                }

                Section("Photos") {
                    if !existingPaths.isEmpty || !newImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(existingPaths, id: \.self) { path in
                                    if let img = SeedManager.loadImage(path: path) {
                                        ExistingImageTile(image: img) {
                                            existingPaths.removeAll { $0 == path }
                                            SeedManager.deleteImage(path: path)
                                        }
                                    }
                                }
                                ForEach(Array(newImages.enumerated()), id: \.offset) { index, img in
                                    ExistingImageTile(image: img) {
                                        newImages.remove(at: index)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("Add Photos", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: pickerItems) { _, items in
                        loadPickerItems(items)
                    }
                }

                Section("Weekly Schedule") {
                    ForEach($schedule) { $entry in
                        HStack {
                            Text(entry.day)
                                .frame(width: 100, alignment: .leading)
                            TextField("Hours", text: $entry.hours)
                                .foregroundStyle(Color.secondary)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadExistingCar() }
        }
    }

    // MARK: - Logic

    private func loadExistingCar() {
        guard let car else { return }
        name = car.name
        type = car.type
        priceLevel = car.priceLevel
        neighborhood = car.neighborhood
        isAvailable = car.isAvailable
        availableFrom = car.availableFrom
        details = car.details
        address = car.address
        latitude = String(car.latitude)
        longitude = String(car.longitude)
        logoInitials = car.logoInitials
        logoColor = car.logoColor
        schedule = car.schedule
        existingPaths = car.imagePaths
    }

    private func loadPickerItems(_ items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data) = result, let data, let image = UIImage(data: data) {
                    DispatchQueue.main.async { newImages.append(image) }
                }
            }
        }
        pickerItems = []
    }

    private func save() {
        let rgb = logoColor.rgbComponents
        let lat = Double(latitude) ?? 18.4861
        let lon = Double(longitude) ?? -69.9312

        let target = car ?? CarModel(
            name: name, type: type, priceLevel: priceLevel, neighborhood: neighborhood
        )

        // Save any new images
        var allPaths = existingPaths
        for (index, image) in newImages.enumerated() {
            let nextIndex = existingPaths.count + index
            if let path = try? SeedManager.saveImage(image, forCar: target.id, index: nextIndex) {
                allPaths.append(path)
            }
        }

        target.name = name
        target.type = type
        target.priceLevel = priceLevel
        target.neighborhood = neighborhood
        target.isAvailable = isAvailable
        target.availableFrom = availableFrom
        target.details = details
        target.address = address
        target.latitude = lat
        target.longitude = lon
        target.logoColorR = rgb.r
        target.logoColorG = rgb.g
        target.logoColorB = rgb.b
        target.logoInitials = logoInitials
        target.schedule = schedule
        target.imagePaths = allPaths

        if car == nil { context.insert(target) }
        dismiss()
    }
}

// MARK: - Helpers

private struct ExistingImageTile: View {
    let image: UIImage
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .background(Color.black.opacity(0.5), in: Circle())
            }
            .padding(4)
        }
    }
}

extension Color {
    var rgbComponents: (r: Double, g: Double, b: Double) {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }
}
