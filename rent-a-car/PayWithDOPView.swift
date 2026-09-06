//
//  PayWithDOPView.swift
//  rent-a-car
//

import SwiftUI

struct PayWithDOPView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var carsStore: CarsStore
    @EnvironmentObject private var vehicleStatusStore: VehicleStatusStore
    @State private var selectedCar: Car?

    var body: some View {
        NavigationStack {
            List(carsStore.cars) { car in
                let available = vehicleStatusStore.isAvailable(car)
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
                                Text(available ? "Available" : "In Use")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(available ? .green : .red)
                                Text("•")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                                Text(available ? "Pick up now" : "Available \(car.availableFrom)")
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
        .environmentObject(CarsStore())
        .environmentObject(VehicleStatusStore())
}
