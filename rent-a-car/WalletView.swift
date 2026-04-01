//
//  WalletView.swift
//  rent-a-car
//

import SwiftUI

struct WalletView: View {
    @Binding var showAdmin: Bool

    @State private var showSaved = false
    @State private var showPaywall = false
    @State private var showCustomerCenter = false
    @State private var balanceInDOP = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BalanceCardView(balanceInDOP: $balanceInDOP)

                    UpgradeToProCardView(showPaywall: $showPaywall)

                    CompleteProfileCardView()
                    RecentActivityCardView()
                    OffersSection()
                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGray6))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { showSaved = true } label: {
                            Label("Profile", systemImage: "person")
                        }
                        Button { showAdmin = true } label: {
                            Label("Manage Vehicles", systemImage: "wrench.and.screwdriver")
                        }
                    } label: {
                        Image(systemName: "person")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {} label: {
                            Text("Refer")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .overlay(Capsule().stroke(Color.primary, lineWidth: 1.5))
                        }
                        Button {} label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSaved) {
            SavedView()
        }
        // RevenueCat Paywall sheet
        .sheet(isPresented: $showPaywall) {
            MotoresProPaywallView()
        }
    }
}

// MARK: - Balance Card

struct BalanceCardView: View {
    @Binding var balanceInDOP: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "steeringwheel")
                    .font(.system(size: 20, weight: .semibold))
                Text("ISAAC M")
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(0.8)
            }
            .padding(.bottom, 28)

            Text("1,000")
                .font(.system(size: 52, weight: .bold))

            HStack {
                HStack(spacing: 6) {
                    Text("YOUR BALANCE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .tracking(0.6)
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                // DOP / USD toggle
                HStack(spacing: 0) {
                    Button { balanceInDOP = true } label: {
                        Text("DOP")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(balanceInDOP ? Color.black : Color.clear)
                            .foregroundStyle(balanceInDOP ? .white : Color.secondary)
                            .clipShape(Capsule())
                    }
                    Button { balanceInDOP = false } label: {
                        Text("USD")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(!balanceInDOP ? Color.black : Color.clear)
                            .foregroundStyle(!balanceInDOP ? .white : Color.secondary)
                            .clipShape(Capsule())
                    }
                }
                .background(Color(.systemGray5))
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Complete Profile Card

struct CompleteProfileCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Complete your profile")
                .font(.system(size: 17, weight: .semibold))

            VStack(spacing: 0) {
                ProfileCheckRow(title: "Add a payment method", isChecked: false)
                Divider().padding(.leading, 42)
                ProfileCheckRow(title: "Upload a Profile Picture", isChecked: true)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProfileCheckRow: View {
    let title: String
    let isChecked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray3), lineWidth: 2)
                    .frame(width: 28, height: 28)
                if isChecked {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Text(title)
                .font(.system(size: 16))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Recent Activity Card

struct RecentActivityCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Activity")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(.bottom, 12)

            ForEach(Array(sampleActivity.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider() }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                        Text(item.date)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.amount)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(item.amount.hasPrefix("+") ? Color(red: 0.2, green: 0.5, blue: 0.9) : Color.primary)
                        Text(item.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Offers Section

struct OffersSection: View {
    @EnvironmentObject private var carsStore: CarsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MOTORES OFFERS")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(.systemGray3))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(carsStore.cars.prefix(4)) { car in
                        VStack(alignment: .leading, spacing: 0) {
                            CarHeroView(car: car, height: 110)
                                .frame(width: 180)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(car.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                                Text("\(car.type) • \(car.neighborhood)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(10)
                        }
                        .frame(width: 180)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
}

// MARK: - Upgrade to Pro Card

/// Shown when the user does not have the Pro entitlement.
/// Tapping it opens the RevenueCat Paywall.
struct UpgradeToProCardView: View {
    @Binding var showPaywall: Bool

    var body: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Motores RD Pro")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text("Monthly & yearly plans available")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.secondary)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pro Status Card

/// Shown when the user has an active Pro entitlement.
/// Tapping "Manage" opens RevenueCat Customer Center.
struct ProStatusCardView: View {
    @Binding var showCustomerCenter: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 3) {
                Text("Motores RD Pro")
                    .font(.system(size: 15, weight: .semibold))
                Text("Active subscription")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button("Manage") { showCustomerCenter = true }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.black)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    WalletView(showAdmin: .constant(false))
        .safeAreaInset(edge: .bottom) {
            BottomBar(
                selectedTab: .constant(.wallet),
                showRentSheet: .constant(false)
            )
        }
}
