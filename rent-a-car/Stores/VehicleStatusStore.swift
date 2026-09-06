import FirebaseFirestore
import Foundation

/// App-wide cache of live vehicle "in use" state, keyed by `Car.vehicleStatusKey`.
/// One listener for the whole collection backs every screen (map, car detail,
/// checkout, admin), so the on/off switch a dealer flips is reflected everywhere —
/// including on a second dealer's listing of the same physical car — in real time.
@MainActor
final class VehicleStatusStore: ObservableObject {
    @Published private(set) var statusByKey: [String: VehicleStatus] = [:]
    @Published var lastErrorMessage: String?

    private let repo: VehicleStatusRepository
    private var listener: ListenerRegistration?

    init(repo: VehicleStatusRepository? = nil) {
        self.repo = repo ?? VehicleStatusRepository()
    }

    func start() {
        guard listener == nil else { return }
        listener = repo.listenAll { [weak self] statuses in
            self?.statusByKey = statuses
        } onError: { [weak self] error in
            self?.lastErrorMessage = error.localizedDescription
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func clearError() {
        lastErrorMessage = nil
    }

    /// True if this car (or another dealer's listing of the same physical car) is
    /// currently marked in use. Falls back to the listing's own `isAvailable` flag
    /// until anyone has ever flipped the switch, so untouched listings behave as before.
    func isInUse(_ car: Car) -> Bool {
        statusByKey[car.vehicleStatusKey]?.inUse ?? !car.isAvailable
    }

    func isAvailable(_ car: Car) -> Bool {
        !isInUse(car)
    }

    func activeBookingId(for car: Car) -> String? {
        statusByKey[car.vehicleStatusKey]?.activeBookingId
    }

    func setInUse(_ car: Car, inUse: Bool, dealerId: String, activeBookingId: String? = nil) async throws {
        try await repo.setInUse(key: car.vehicleStatusKey, inUse: inUse, dealerId: dealerId, activeBookingId: activeBookingId)
    }
}
