import SwiftUI

/// The literal on/off switch a dealer flips to mark a car as currently out with a
/// renter. Writes straight to the shared `VehicleStatus` doc, so if this car is
/// cross-listed by another dealer under the same `sharedVehicleCode`, their listing
/// flips too — the whole point being neither dealer can accidentally hand out a car
/// the other already has on the road.
struct InUseSwitch: View {
    let car: Car
    @EnvironmentObject private var vehicleStatusStore: VehicleStatusStore

    @State private var isToggling = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        let inUse = vehicleStatusStore.isInUse(car)
        HStack(spacing: 10) {
            Text(inUse ? "In Use" : "Available")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(inUse ? Color.red : Color.green)
            Toggle("", isOn: Binding(
                get: { inUse },
                set: { toggle(to: $0) }
            ))
            .labelsHidden()
            .tint(.red)
            .disabled(isToggling)
        }
        .alert("Couldn't Update Status", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
    }

    private func toggle(to newValue: Bool) {
        guard !isToggling else { return }
        isToggling = true
        Task {
            do {
                try await vehicleStatusStore.setInUse(car, inUse: newValue, dealerId: car.ownerId)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isToggling = false
        }
    }
}

#Preview {
    InUseSwitch(car: sampleCars[0])
        .environmentObject(VehicleStatusStore())
        .padding()
}
