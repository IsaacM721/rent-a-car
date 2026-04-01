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
    @StateObject private var auth = AuthService()
    @StateObject private var carsStore = CarsStore()

    init() {
        // Configure Firebase
        FirebaseApp.configure()
        #if DEBUG
        assert(FirebaseApp.app() != nil, "Firebase failed to configure. Check GoogleService-Info.plist is in the app target and Copy Bundle Resources.")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environmentObject(auth)
                .environmentObject(carsStore)
                .onAppear { carsStore.start() }
        }
    }
}

// MARK: - Root Gate
// Decides which screen to show based on auth + onboarding state.

struct RootGateView: View {
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        Group {
            if !auth.isLoggedIn {
                // Not logged in → phone auth
                PhoneAuthView()
            } else if !auth.hasCompletedOnboarding {
                // Logged in but first time → onboarding wizard
                OnboardingView {
                    auth.hasCompletedOnboarding = true
                }
            } else {
                // Fully onboarded → main app
                MainAppView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.isLoggedIn)
        .animation(.easeInOut(duration: 0.35), value: auth.hasCompletedOnboarding)
    }
}

// MARK: - Main App (previously AppRootView)

struct MainAppView: View {
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
