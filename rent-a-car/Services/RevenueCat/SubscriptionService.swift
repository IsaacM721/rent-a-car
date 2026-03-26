//
//  SubscriptionService.swift
//  rent-a-car
//
//  Manages all RevenueCat interactions: configuration, offerings,
//  purchases, entitlement checks, and customer info.
//

import Combine
import Foundation
import RevenueCat

// MARK: - Constants

enum RevenueCatConfig {
    /// Public SDK key — replace with production key before App Store release.
    static let apiKey = "test_gTYibxJnUasKpAEHyovKygjtbNk"

    /// The entitlement identifier configured in the RevenueCat dashboard.
    static let proEntitlement = "Motores RD Pro"

    /// Offering identifiers configured in the RevenueCat dashboard.
    enum Offering {
        static let `default` = "default"
    }

    /// Product identifiers as configured in App Store Connect / RevenueCat dashboard.
    enum Product {
        static let monthly = "monthly"
        static let yearly  = "yearly"
    }
}

// MARK: - SubscriptionService

/// Observable service that wraps RevenueCat SDK interactions.
/// Inject this as an environment object so any view can react to subscription changes.
@MainActor
final class SubscriptionService: ObservableObject {

    // MARK: Published State

    /// Whether the current user has an active "Motores RD Pro" entitlement.
    @Published private(set) var isPro: Bool = false

    /// Latest customer info fetched from RevenueCat.
    @Published private(set) var customerInfo: CustomerInfo?

    /// Available offerings from RevenueCat; nil until fetched.
    @Published private(set) var offerings: Offerings?

    /// Non-nil while a network or purchase operation is in flight.
    @Published private(set) var isLoading: Bool = false

    /// Surfaces any error to the UI.
    @Published var lastError: SubscriptionError?

    // MARK: Init

    init() {
        // Observe CustomerInfo updates pushed by the SDK in real-time.
        // This fires whenever a purchase is made, subscription renews, etc.
        Task { await listenForCustomerInfoUpdates() }
    }

    // MARK: - Public API

    /// Call once from the app entry point to configure the RevenueCat SDK.
    static func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif

        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
    }

    /// Loads current customer info and available offerings.
    /// Safe to call on every app launch / foreground.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        await fetchCustomerInfo()
        await fetchOfferings()
    }

    /// Purchase a package from the current default offering.
    /// - Parameter package: The `Package` to purchase.
    func purchase(_ package: Package) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(customerInfo: result.customerInfo)
        } catch ErrorCode.purchaseCancelledError {
            // User cancelled — not an error worth surfacing
        } catch {
            lastError = .purchase(error)
        }
    }

    /// Restore previous purchases (required button in App Store apps).
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(customerInfo: info)
        } catch {
            lastError = .restore(error)
        }
    }

    /// Returns the default offering's packages.
    var availablePackages: [Package] {
        offerings?.current?.availablePackages ?? []
    }

    // MARK: - Private Helpers

    private func fetchCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(customerInfo: info)
        } catch {
            lastError = .fetch(error)
        }
    }

    private func fetchOfferings() async {
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            lastError = .fetch(error)
        }
    }

    private func apply(customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo
        self.isPro = customerInfo.entitlements[RevenueCatConfig.proEntitlement]?.isActive == true
    }

    /// Opens a long-lived async task that receives CustomerInfo updates pushed by RevenueCat.
    private func listenForCustomerInfoUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(customerInfo: info)
        }
    }
}

// MARK: - SubscriptionError

enum SubscriptionError: LocalizedError, Identifiable {
    case fetch(Error)
    case purchase(Error)
    case restore(Error)

    var id: String { errorDescription ?? UUID().uuidString }

    var errorDescription: String? {
        switch self {
        case .fetch(let e):    return "Could not load subscription info: \(e.localizedDescription)"
        case .purchase(let e): return "Purchase failed: \(e.localizedDescription)"
        case .restore(let e):  return "Restore failed: \(e.localizedDescription)"
        }
    }
}
