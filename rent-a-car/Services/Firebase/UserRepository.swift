import FirebaseFirestore
import Foundation

/// Manages the user document in Firestore: `users/{uid}`
final class UserRepository {
    private let db = Firestore.firestore()

    private func userDoc(uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    // MARK: - Fetch

    func fetchUser(uid: String) async throws -> UserProfile? {
        let snapshot = try await userDoc(uid: uid).getDocument()
        return try? snapshot.data(as: UserProfile.self)
    }

    // MARK: - Create / update

    func saveUser(_ profile: UserProfile) async throws {
        try await userDoc(uid: profile.uid).setData(from: profile, merge: true)
    }

    func markPassportVerified(uid: String, passportURL: String) async throws {
        try await userDoc(uid: uid).updateData([
            "passportURL": passportURL,
            "isIdentityVerified": true
        ])
    }
}

// MARK: - UserProfile model

struct UserProfile: Codable, Identifiable {
    var uid: String
    var phone: String
    var passportURL: String?
    var isIdentityVerified: Bool

    var id: String { uid }

    init(uid: String, phone: String) {
        self.uid = uid
        self.phone = phone
        self.passportURL = nil
        self.isIdentityVerified = false
    }
}
