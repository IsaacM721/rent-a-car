//
//  CarHeroView.swift
//  rent-a-car
//

import SwiftUI
import UIKit

struct CarHeroView: View {
    let car: CarModel
    var height: CGFloat = 200

    var body: some View {
        Group {
            if let firstPath = car.imagePaths.first,
               let image = SeedManager.loadImage(path: firstPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "car.fill")
                        .font(.system(size: height * 0.25))
                        .foregroundStyle(Color(.systemGray3))
                }
            }
        }
        .frame(height: height)
        .clipped()
    }
}
