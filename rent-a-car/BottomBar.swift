//
//  BottomBar.swift
//  rent-a-car
//

import SwiftUI

enum AppTab {
    case map, wallet, saved
}

struct BottomBar: View {
    @Binding var selectedTab: AppTab
    @Binding var showRentSheet: Bool

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(icon: "map", label: "Map", isSelected: selectedTab == .map) {
                selectedTab = .map
            }
            TabBarButton(icon: "wallet.bifold", label: "Wallet", isSelected: selectedTab == .wallet) {
                selectedTab = .wallet
            }
            TabBarButton(icon: "bookmark", label: "Saved", isSelected: selectedTab == .saved) {
                selectedTab = .saved
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview sample data

struct ActivityItem: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let amount: String
    let subtitle: String
}

let sampleActivity: [ActivityItem] = [
    ActivityItem(title: "Toyota Corolla 2024", date: "Mar 10, 2026", amount: "-$180.00", subtitle: "3 days"),
    ActivityItem(title: "Balance Top-up",       date: "Mar 5, 2026",  amount: "+1,000 DOP", subtitle: "Via transfer"),
    ActivityItem(title: "Honda Civic 2023",     date: "Feb 28, 2026", amount: "-$120.00", subtitle: "2 days"),
]

let sampleCars: [Car] = [
    Car(
        docId: "sample-1",
        name: "Toyota Corolla 2024",
        type: "Sedan",
        priceLevel: "$$",
        neighborhood: "Naco",
        isAvailable: true,
        availableFrom: "9:00 AM",
        details: "Clean and reliable daily driver.",
        address: "Santo Domingo",
        latitude: 18.4861,
        longitude: -69.9312,
        photoURLs: [],
        logo: .init(r: 0.2, g: 0.2, b: 0.8, initials: "TC"),
        isActive: true
    ),
    Car(
        docId: "sample-2",
        name: "Honda Civic 2023",
        type: "Sedan",
        priceLevel: "$",
        neighborhood: "Piantini",
        isAvailable: true,
        availableFrom: "9:00 AM",
        details: "Great on gas, easy to park.",
        address: "Santo Domingo",
        latitude: 18.4761,
        longitude: -69.9412,
        photoURLs: [],
        logo: .init(r: 0.2, g: 0.2, b: 0.8, initials: "HC"),
        isActive: true
    ),
    Car(
        docId: "sample-3",
        name: "Jeep Wrangler 2022",
        type: "SUV",
        priceLevel: "$$$",
        neighborhood: "Serralles",
        isAvailable: false,
        availableFrom: "Tomorrow 10:00 AM",
        details: "Perfect for weekend trips.",
        address: "Santo Domingo",
        latitude: 18.4961,
        longitude: -69.9212,
        photoURLs: [],
        logo: .init(r: 0.2, g: 0.2, b: 0.8, initials: "JW"),
        isActive: true
    ),
    Car(
        docId: "sample-4",
        name: "Kia Sportage 2024",
        type: "SUV",
        priceLevel: "$$",
        neighborhood: "Gazcue",
        isAvailable: true,
        availableFrom: "9:00 AM",
        details: "Comfortable and spacious.",
        address: "Santo Domingo",
        latitude: 18.4661,
        longitude: -69.9512,
        photoURLs: [],
        logo: .init(r: 0.2, g: 0.2, b: 0.8, initials: "KS"),
        isActive: true
    ),
]
