import FirebaseFirestore
import Foundation

/// A fleet owner who lists vehicles. One `Dealer` doc per Firebase Auth uid,
/// document id == uid, created during onboarding.
struct Dealer: Codable, Identifiable {
    @DocumentID var docId: String?
    var id: String { docId ?? "" }

    var businessName: String
    var phone: String
    var zoneId: String
    var zoneDisplayName: String
    @ServerTimestamp var createdAt: Timestamp?
}
