//
//  CarLogoView.swift
//  rent-a-car
//

import SwiftUI

struct CarLogoView: View {
    let car: CarModel
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(car.logoColor)
            Text(car.logoInitials)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
