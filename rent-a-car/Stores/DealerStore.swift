import Foundation

@MainActor
final class DealerStore: ObservableObject {
    @Published private(set) var currentDealer: Dealer?
    @Published private(set) var isLoading = false
    @Published var lastErrorMessage: String?

    var isOnboarded: Bool { currentDealer != nil }

    private let repo: DealerRepository

    init(repo: DealerRepository? = nil) {
        self.repo = repo ?? DealerRepository()
    }

    /// Refreshes onboarding state for the signed-in user. Call whenever the
    /// authenticated uid changes (including sign-out, where uid is nil).
    func refresh(uid: String?) async {
        guard let uid, !uid.isEmpty else {
            currentDealer = nil
            return
        }
        isLoading = true
        do {
            currentDealer = try await repo.fetchDealer(uid: uid)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func completeOnboarding(uid: String, businessName: String, phone: String, zoneId: String, zoneDisplayName: String) async throws {
        try await repo.createDealer(uid: uid, businessName: businessName, phone: phone, zoneId: zoneId, zoneDisplayName: zoneDisplayName)
        await refresh(uid: uid)
    }

    func clearError() {
        lastErrorMessage = nil
    }
}
