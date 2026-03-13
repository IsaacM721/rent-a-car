//
//  SavedView.swift
//  rent-a-car
//

import SwiftUI

enum SavedTab: String, CaseIterable {
    case favorites  = "Favorites"
    case wantToRent = "Want to Rent"
    case rented     = "Rented"
}

struct SavedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SavedTab = .favorites

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                HStack(spacing: 0) {
                    ForEach(SavedTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selectedTab == tab ? .white : Color.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(selectedTab == tab ? Color.black : Color.clear)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(4)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                // Empty state
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7]))
                        .foregroundStyle(Color(.systemGray3))
                        .padding(.horizontal, 16)

                    VStack(spacing: 20) {
                        Text("Nothing Saved")
                            .font(.system(size: 22, weight: .bold))
                        Text("Cars you save will\nappear here")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                        Button { dismiss() } label: {
                            Text("Browse cars")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.primary)
                                .padding(.horizontal, 44)
                                .padding(.vertical, 14)
                                .overlay(Capsule().stroke(Color.primary, lineWidth: 1.5))
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGray6))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .padding(8)
                            .background(Color(.systemGray5), in: Circle())
                    }
                }
            }
        }
    }
}

#Preview {
    SavedView()
}
