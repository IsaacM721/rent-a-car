//
//  SubscriptionService.swift
//  rent-a-car
//
//  Stub — RevenueCat package not yet added to Xcode project.
//  Add via: File → Add Package Dependencies → https://github.com/RevenueCat/purchases-ios
//  Then restore the full implementation from git history.
//

import Combine
import Foundation

// MARK: - SubscriptionService (stub)

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: Error? = nil

    static func configure() {
        // TODO: configure RevenueCat after adding package
    }

    func refresh() async {
        // TODO: fetch customer info from RevenueCat
    }
}
