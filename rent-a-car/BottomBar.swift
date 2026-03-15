//
//  BottomBar.swift
//  rent-a-car
//

import SwiftUI

enum Tab {
    case map, wallet, saved
}

struct BottomBar: View {
    @Binding var selectedTab: Tab
    @Binding var showRentSheet: Bool

    var body: some View {
        HStack {
            tabButton(.map, icon: "map", label: "Map")
            Spacer()
            // Center rent button
            Button { showRentSheet = true } label: {
                Image(systemName: "car.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(Color.black, in: Circle())
            }
            Spacer()
            tabButton(.wallet, icon: "wallet.pass", label: "Wallet")
        }
        .padding(.horizontal, 32)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Color(.systemBackground))
    }

    private func tabButton(_ tab: Tab, icon: String, label: String) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
        }
    }
}
