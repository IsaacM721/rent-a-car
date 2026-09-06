import FirebaseFirestore
import Foundation

/// A renter's reservation of a car. This is a client-trusted MVP record — there is no
/// backend enforcing payment or availability yet, so the source of truth for "can this
/// car be booked right now" is `VehicleStatus.inUse`, checked and flipped at the same
/// time this document is created.
struct BookingDoc: Codable, Identifiable {
    @DocumentID var docId: String?
    var id: String { docId ?? "" }

    var carId: String
    var carName: String
    var vehicleStatusKey: String
    var dealerId: String
    var renterId: String
    var startDate: Date
    var endDate: Date
    var total: Double
    var status: String // "active", "completed", "cancelled"
    @ServerTimestamp var createdAt: Timestamp?
}
