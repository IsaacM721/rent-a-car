import FirebaseFirestore
import Foundation

final class DealerRepository {
    private let db = Firestore.firestore()

    private var dealersCollection: CollectionReference {
        db.collection("dealers")
    }

    func fetchDealer(uid: String) async throws -> Dealer? {
        let snapshot = try await dealersCollection.document(uid).getDocument()
        return try? snapshot.data(as: Dealer.self)
    }

    func createDealer(uid: String, businessName: String, phone: String, zoneId: String, zoneDisplayName: String) async throws {
        let dealer = Dealer(
            docId: nil,
            businessName: businessName,
            phone: phone,
            zoneId: zoneId,
            zoneDisplayName: zoneDisplayName,
            createdAt: nil
        )
        try await FirebaseAsync.withCheckedThrowingContinuation { (done: @escaping (Result<Void, Error>) -> Void) in
            do {
                try dealersCollection.document(uid).setData(from: dealer, merge: true) { error in
                    if let error { done(.failure(error)) }
                    else { done(.success(())) }
                }
            } catch {
                done(.failure(error))
            }
        }
    }
}
