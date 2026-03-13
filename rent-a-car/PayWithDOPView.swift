//
//  PayWithDOPView.swift
//  rent-a-car
//

import SwiftUI
import SwiftData

struct PayWithDOPView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CarModel.name) var cars: [CarModel]
    @State private var selectedCar: CarModel?

    var body: some View {
        NavigationStack {
            List(cars) { car in
                Button {
                    selectedCar = car
                } label: {
                    HStack(spacing: 14) {
                        CarLogoView(car: car, size: 60)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(car.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Text("\(car.type) / \(car.priceLevel) / \(car.neighborhood)")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                            HStack(spacing: 4) {
                                Text(car.isAvailable ? "Available" : "Unavailable")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(car.isAvailable ? .green : .red)
                                Text("•")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                                Text(car.isAvailable ? "Pick up now" : "Available \(car.availableFrom)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Pay with DOP")
            .navigationBarTitleDisplayMode(.inline)
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
        .sheet(item: $selectedCar) { car in
            CarDetailView(car: car)
        }
    }
}

#Preview {
    PayWithDOPView()
}
