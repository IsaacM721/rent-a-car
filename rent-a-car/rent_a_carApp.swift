//
//  rent_a_carApp.swift
//  rent-a-car
//
//  Created by Isaac Mendez on 3/10/26.
//

import SwiftUI
import SwiftData

@main
struct rent_a_carApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CarModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct AppRootView: View {
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
    }
}
