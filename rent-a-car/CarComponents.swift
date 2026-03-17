//
//  CarComponents.swift
//  rent-a-car
//

import SwiftUI

// MARK: - CarHeroView
// Displays the car's first photo (or a placeholder gradient) at a given height.

struct CarHeroView: View {
    let car: Car
    var height: CGFloat = 200

    var body: some View {
        Group {
            if let urlString = car.photoURLs.first, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [car.logoColor.opacity(0.6), car.logoColor.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "car.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.4))
        )
    }
}

// MARK: - CarLogoView
// Displays a rounded square with the car's initials on its logo color.

struct CarLogoView: View {
    let car: Car
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(car.logoColor)
                .frame(width: size, height: size)
            Text(car.logoInitials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
