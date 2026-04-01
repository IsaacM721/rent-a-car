import FirebaseAuth
import Foundation

@MainActor
final class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var verificationID: String?

    var isLoggedIn: Bool { currentUser != nil }

    init() {
        currentUser = Auth.auth().currentUser
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

    // MARK: - Send OTP

    func sendOTP(to phoneNumber: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let id = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
                    if let error {
                        cont.resume(throwing: error)
                    } else if let verificationID {
                        cont.resume(returning: verificationID)
                    } else {
                        cont.resume(throwing: NSError(domain: "AuthService", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No verification ID returned."]))
                    }
                }
            }
            verificationID = id
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Verify OTP

    func verifyOTP(_ code: String) async {
        guard let verificationID else {
            errorMessage = "No verification in progress. Please request a new code."
            return
        }
        isLoading = true
        errorMessage = nil
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        do {
            let result = try await Auth.auth().signIn(with: credential)
            currentUser = result.user
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        try? Auth.auth().signOut()
        currentUser = nil
    }

    func clearError() {
        errorMessage = nil
    }
}
