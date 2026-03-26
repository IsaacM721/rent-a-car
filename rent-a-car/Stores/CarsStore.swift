import FirebaseFirestore
import Foundation
import Combine

@MainActor
final class CarsStore: ObservableObject {
    @Published private(set) var cars: [Car] = []
    @Published private(set) var lastErrorMessage: String?

    private let repo: CarsRepository
    private var listener: ListenerRegistration?

    init(repo: CarsRepository? = nil) {
        self.repo = repo ?? CarsRepository()
    }

    func start() {
        guard listener == nil else { return }
        listener = repo.listenActiveCars { [weak self] cars in
            guard let self else { return }
            self.lastErrorMessage = nil
            self.cars = cars.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    func create(car: Car) async throws -> String {
        try await repo.createCar(car)
    }

    func update(car: Car) async throws {
        try await repo.updateCar(car)
    }

    func delete(id: String) async throws {
        try await repo.deleteCar(id: id)
    }
}

