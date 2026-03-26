//
//  rent_a_carApp.swift
//  rent-a-car
//
//  Created by Isaac Mendez on 3/10/26.
//
import FirebaseCore
import RevenueCat
import SwiftUI

@main
struct rent_a_carApp: App {
    @StateObject private var carsStore = CarsStore()
    @StateObject private var subscriptionService = SubscriptionService()

    init() {
        // Configure Firebase
        FirebaseApp.configure()
        #if DEBUG
        assert(FirebaseApp.app() != nil, "Firebase failed to configure. Check GoogleService-Info.plist is in the app target and Copy Bundle Resources.")
        #endif

        // Configure RevenueCat — must happen before any Purchases.shared calls
        SubscriptionService.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(carsStore)
                .environmentObject(subscriptionService)
                .onAppear { carsStore.start() }
                .task { await subscriptionService.refresh() }
        }
    }
}

struct AppRootView: View {
    @EnvironmentObject private var carsStore: CarsStore
    @State private var selectedTab: AppTab = .map
    @State private var showRentSheet = false
    @State private var showAdmin = false
    @State private var showLaunch = true
    @State private var launchOpacity: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Main app content
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedTab {
                    case .map:
                        MapView()
                    case .wallet:
                        WalletView(showAdmin: $showAdmin)
                    case .saved:
                        SavedView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)

                BottomBar(selectedTab: $selectedTab, showRentSheet: $showRentSheet)
            }
            .sheet(isPresented: $showAdmin) {
                AdminView()
            }
            .alert("Fleet sync error", isPresented: Binding(
                get: { carsStore.lastErrorMessage != nil },
                set: { if !$0 { carsStore.clearError() } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(carsStore.lastErrorMessage ?? "Unknown error.")
            }

            // Launch screen overlay
            if showLaunch {
                LaunchScreenView()
                    .opacity(launchOpacity)
                    .ignoresSafeArea()
                    .onAppear {
                        // Hold for 2.2s then fade out
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                launchOpacity = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                showLaunch = false
                            }
                        }
                    }
            }
        }
    }
}
