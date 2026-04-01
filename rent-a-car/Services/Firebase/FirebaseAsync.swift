import Foundation

enum FirebaseAsync {
    static func withCheckedThrowingContinuation<T>(
        _ body: @escaping (@escaping (Result<T, Error>) -> Void) throws -> Void
    ) async throws -> T {
        try await _Concurrency.withCheckedThrowingContinuation { continuation in
            do {
                try body { result in
                    continuation.resume(with: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

