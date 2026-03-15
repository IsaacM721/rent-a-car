//
//  SampleData.swift
//  rent-a-car
//

import Foundation

// MARK: - Activity

struct ActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let amount: String
    let subtitle: String
}

let sampleActivity: [ActivityItem] = [
    ActivityItem(title: "Toyota Corolla",  date: "Mar 10", amount: "-$180.00", subtitle: "3-day rental"),
    ActivityItem(title: "Balance Top-up",  date: "Mar 8",  amount: "+$500.00", subtitle: "Bank transfer"),
    ActivityItem(title: "Hyundai Tucson",  date: "Mar 3",  amount: "-$300.00", subtitle: "3-day rental"),
]

// MARK: - Sample Cars (for previews)

let sampleCars: [CarModel] = [
    CarModel(
        name: "Toyota Corolla 2024",
        type: "Sedan",
        priceLevel: "$$",
        neighborhood: "Naco",
        details: "Reliable and fuel-efficient sedan, perfect for city driving.",
        address: "Av. Tiradentes #12, Naco",
        logoInitials: "TC"
    ),
    CarModel(
        name: "Hyundai Tucson 2023",
        type: "SUV",
        priceLevel: "$$$",
        neighborhood: "Piantini",
        details: "Spacious SUV with modern safety features.",
        address: "Av. Abraham Lincoln #45, Piantini",
        logoInitials: "HT"
    ),
]
