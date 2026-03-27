import FirebaseStorage
import Foundation
import UIKit

final class StorageService {
    private let storage = Storage.storage()

    func uploadJPEG(_ image: UIImage, path: String, compressionQuality: CGFloat = 0.85) async throws -> URL {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw NSError(domain: "StorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode JPEG"])
        }

        let ref = storage.reference(withPath: path)
        _ = try await FirebaseAsync.withCheckedThrowingContinuation { (done: @escaping (Result<Void, Error>) -> Void) in
            ref.putData(data, metadata: nil) { _, error in
                if let error { done(.failure(error)) }
                else { done(.success(())) }
            }
        }

        return try await FirebaseAsync.withCheckedThrowingContinuation { (done: @escaping (Result<URL, Error>) -> Void) in
            ref.downloadURL { url, error in
                if let error { done(.failure(error)) }
                else if let url { done(.success(url)) }
                else { done(.failure(NSError(domain: "StorageService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing download URL"]))) }
            }
        }
    }
}

