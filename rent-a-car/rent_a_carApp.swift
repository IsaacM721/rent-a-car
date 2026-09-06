//
//  rent_a_carApp.swift
//  rent-a-car
//
//  Created by Isaac Mendez on 3/10/26.
//
import FirebaseCore
import SwiftUI

@main
struct rent_a_carApp: App {
    @StateObject private var carsStore = CarsStore()
    @StateObject private var subscriptionService = SubscriptionService()
    @StateObject private var authService = AuthService()
    @StateObject private var dealerStore = DealerStore()
    @StateObject private var vehicleStatusStore = VehicleStatusStore()

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
            Group {
                if authService.isLoggedIn {
                    AppRootView()
                        .environmentObject(carsStore)
                        .environmentObject(subscriptionService)
                        .environmentObject(authService)
                        .environmentObject(dealerStore)
                        .environmentObject(vehicleStatusStore)
                        .onAppear {
                            carsStore.start()
                            vehicleStatusStore.start()
                        }
                        .task { await subscriptionService.refresh() }
                        .task(id: authService.currentUser?.uid) {
                            await dealerStore.refresh(uid: authService.currentUser?.uid)
                        }
                } else {
                    PhoneAuthView()
                        .environmentObject(authService)
                }
            }
        }
    }
}

struct AppRootView: View {
    @EnvironmentObject private var carsStore: CarsStore
    @State private var selectedTab: AppTab = .map
    @State private var showRentSheet = false
    @State private var showAdmin = false

    var body: some View {
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
    }
}
