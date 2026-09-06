import FirebaseFirestore
import Foundation

final class BookingRepository {
    private let db = Firestore.firestore()

    private var bookingsCollection: CollectionReference {
        db.collection("bookings")
    }

    /// Creates the booking record and returns its id. Does not touch `VehicleStatus` —
    /// callers (see `RentCheckoutView`) flip that separately so the "car is in use"
    /// switch stays the single source of truth for availability.
    func createBooking(_ booking: BookingDoc) async throws -> String {
        let ref = bookingsCollection.document()
        try await FirebaseAsync.withCheckedThrowingContinuation { (done: @escaping (Result<Void, Error>) -> Void) in
            do {
                try ref.setData(from: booking, merge: false) { error in
                    if let error { done(.failure(error)) }
                    else { done(.success(())) }
                }
            } catch {
                done(.failure(error))
            }
        }
        return ref.documentID
    }
}
