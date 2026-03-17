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

let sampleCars: [CarModel] = [
    CarModel(name: "Toyota Corolla 2024", type: "Sedan",   priceLevel: "$$",  neighborhood: "Naco",       logoInitials: "TC"),
    CarModel(name: "Honda Civic 2023",    type: "Sedan",   priceLevel: "$",   neighborhood: "Piantini",   logoInitials: "HC"),
    CarModel(name: "Jeep Wrangler 2022",  type: "SUV",     priceLevel: "$$$", neighborhood: "Serralles",  logoInitials: "JW"),
    CarModel(name: "Kia Sportage 2024",   type: "SUV",     priceLevel: "$$",  neighborhood: "Gazcue",     logoInitials: "KS"),
]
