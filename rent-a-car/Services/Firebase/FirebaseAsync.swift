import Foundation

enum FirebaseAsync {
    static func withCheckedThrowingContinuation<T>(
        _ body: (@escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            body { result in
                continuation.resume(with: result)
            }
        }
    }
}

