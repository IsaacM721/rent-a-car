//
//  MotoresProPaywallView.swift
//  rent-a-car
//
//  Stub — RevenueCat package not yet added to Xcode project.
//  Add via: File → Add Package Dependencies → https://github.com/RevenueCat/purchases-ios
//  Then restore the full implementation from git history.
//

import SwiftUI

// MARK: - MotoresProPaywallView (stub)

struct MotoresProPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("Motores RD Pro")
                .font(.system(size: 24, weight: .bold))
            Text("Subscription coming soon.")
                .foregroundStyle(Color.secondary)
            Button("Close") { dismiss() }
                .padding(.top, 8)
        }
        .padding(40)
    }
}

// MARK: - Entitlement Gate Modifier (stub)

extension View {
    /// No-op stub — replace with RevenueCat implementation after adding package.
    func requiresMotoresPro(
        purchaseCompleted: (() -> Void)? = nil,
        restoreCompleted: (() -> Void)? = nil
    ) -> some View {
        self
    }
}

// MARK: - Preview

#Preview {
    MotoresProPaywallView()
}
