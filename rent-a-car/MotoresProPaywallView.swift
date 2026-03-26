//
//  MotoresProPaywallView.swift
//  rent-a-car
//
//  Presents the RevenueCat Paywall for the "Motores RD Pro" entitlement.
//  RevenueCatUI renders the paywall you design in the RevenueCat dashboard,
//  so no manual product UI is needed here.
//

import RevenueCat
import RevenueCatUI
import SwiftUI

// MARK: - MotoresProPaywallView

/// Full-screen wrapper around RevenueCatUI's PaywallView.
/// Dismiss via the close button or after a successful purchase / restore.
struct MotoresProPaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaywallView(displayCloseButton: true)
            // Called after a successful purchase
            .onPurchaseCompleted { customerInfo in
                if customerInfo.entitlements[RevenueCatConfig.proEntitlement]?.isActive == true {
                    dismiss()
                }
            }
            // Called after a successful restore
            .onRestoreCompleted { customerInfo in
                if customerInfo.entitlements[RevenueCatConfig.proEntitlement]?.isActive == true {
                    dismiss()
                }
            }
    }
}

// MARK: - Entitlement Gate Modifier

extension View {
    /// Presents the Motores Pro paywall if the user does not have the Pro entitlement.
    /// - Parameters:
    ///   - purchaseCompleted: Callback with updated CustomerInfo after purchase.
    ///   - restoreCompleted: Callback with updated CustomerInfo after restore.
    func requiresMotoresPro(
        purchaseCompleted: ((CustomerInfo) -> Void)? = nil,
        restoreCompleted: ((CustomerInfo) -> Void)? = nil
    ) -> some View {
        self.presentPaywallIfNeeded(
            requiredEntitlementIdentifier: RevenueCatConfig.proEntitlement
        ) { customerInfo in
            purchaseCompleted?(customerInfo)
        } restoreCompleted: { customerInfo in
            restoreCompleted?(customerInfo)
        }
    }
}

// MARK: - Preview

#Preview {
    MotoresProPaywallView()
        .environmentObject(SubscriptionService())
}
