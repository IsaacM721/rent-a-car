import FirebaseFirestore
import Foundation

/// Live "is this physical car in use right now" state, keyed by `Car.vehicleStatusKey`.
///
/// This is deliberately separate from each dealer's `Car` listing document: when two
/// dealers list the same physical vehicle (via a shared `sharedVehicleCode`), both of
/// their `Car` docs point at the same `VehicleStatus` doc, so toggling the switch on
/// one listing instantly shows up on the other's.
struct VehicleStatus: Codable, Identifiable {
    @DocumentID var docId: String?
    var id: String { docId ?? "" }

    var inUse: Bool
    var updatedByDealerId: String?
    var activeBookingId: String?
    @ServerTimestamp var updatedAt: Timestamp?
}
