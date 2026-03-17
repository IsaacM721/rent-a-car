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

    init() {
        FirebaseApp.configure()
        #if DEBUG
        assert(FirebaseApp.app() != nil, "Firebase failed to configure. Check GoogleService-Info.plist is in the app target and Copy Bundle Resources.")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(carsStore)
                .onAppear { carsStore.start() }
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

            BottomBar(selectedTab: $selectedTab, showRentSheet: $showRentSheet)
        }
        .ignoresSafeArea(edges: .bottom)
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

