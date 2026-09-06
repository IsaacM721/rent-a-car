import FirebaseFirestore
import Foundation

final class VehicleStatusRepository {
    private let db = Firestore.firestore()

    private var statusCollection: CollectionReference {
        db.collection("vehicleStatus")
    }

    /// Listens to every vehicle status doc. The collection stays small (one doc per
    /// physical car ever toggled), so a single always-on listener is simpler than
    /// per-car listeners and keeps shared statuses in sync across dealers for free.
    func listenAll(onChange: @escaping ([String: VehicleStatus]) -> Void, onError: @escaping (Error) -> Void) -> ListenerRegistration {
        statusCollection.addSnapshotListener { snapshot, error in
            if let error {
                onError(error)
                return
            }
            guard let documents = snapshot?.documents else {
                onChange([:])
                return
            }

            var byKey: [String: VehicleStatus] = [:]
            for doc in documents {
                if let status = try? doc.data(as: VehicleStatus.self) {
                    byKey[doc.documentID] = status
                }
            }
            onChange(byKey)
        }
    }

    func setInUse(key: String, inUse: Bool, dealerId: String, activeBookingId: String?) async throws {
        var data: [String: Any] = [
            "inUse": inUse,
            "updatedByDealerId": dealerId,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        data["activeBookingId"] = activeBookingId ?? FieldValue.delete()

        try await FirebaseAsync.withCheckedThrowingContinuation { (done: @escaping (Result<Void, Error>) -> Void) in
            statusCollection.document(key).setData(data, merge: true) { error in
                if let error { done(.failure(error)) }
                else { done(.success(())) }
            }
        }
    }
}
