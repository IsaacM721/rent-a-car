import FirebaseFirestore
import Foundation

final class CarsRepository {
    private let db = Firestore.firestore()

    private var carsCollection: CollectionReference {
        db.collection("cars")
    }

    func listenActiveCars(onChange: @escaping ([Car]) -> Void, onError: @escaping (Error) -> Void) -> ListenerRegistration {
        carsCollection
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError(error)
                    return
                }
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }

                let cars: [Car] = documents.compactMap { doc in
                    try? doc.data(as: Car.self)
                }
                onChange(cars)
            }
    }

    func createCar(_ car: Car) async throws -> String {
        let ref = carsCollection.document()
        var newCar = car
        newCar.docId = ref.documentID
        try await FirebaseAsync.withCheckedThrowingContinuation { (done: @escaping (Result<Void, Error>) -> Void) in
            do {
                try ref.setData(from: newCar, merge: false) { error in
                    if let error { done(.failure(error)) }
                    else { done(.success(())) }
                }
            } catch {
                done(.failure(error))
            }
        }
        return ref.documentID
    }

    func updateCar(_ car: Car) async throws {
        guard let id = car.docId, !id.isEmpty else {
            throw NSError(domain: "CarsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing car docId for update"])
        }
        try await FirebaseAsync.withCheckedThrowingContinuation { (done: @escaping (Result<Void, Error>) -> Void) in
            do {
                try self.carsCollection.document(id).setData(from: car, merge: true) { error in
                    if let error { done(.failure(error)) }
                    else { done(.success(())) }
                }
            } catch {
                done(.failure(error))
            }
        }
    }

    func deleteCar(id: String) async throws {
        try await FirebaseAsync.withCheckedThrowingContinuation { (done: @escaping (Result<Void, Error>) -> Void) in
            self.carsCollection.document(id).delete { error in
                if let error { done(.failure(error)) }
                else { done(.success(())) }
            }
        }
    }
}

