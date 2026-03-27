import Foundation

enum FirebaseAsync {
    static func withCheckedThrowingContinuation<T>(
        _ body: @escaping (@escaping (Result<T, Error>) -> Void) -> Void
    ) async throws -> T {
        try await _Concurrency.withCheckedThrowingContinuation { continuation in
            body { result in
                continuation.resume(with: result)
            }
        }
    }
}

