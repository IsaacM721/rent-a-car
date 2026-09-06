import PhotosUI
import SwiftUI

/// Shown once before the user's first checkout.
/// They take or upload a photo of their passport.
/// On success, the passport URL is saved to Firestore and the user is marked verified.
struct IdentityVerificationView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var passportImage: UIImage?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var didVerify = false

    private let storageService = StorageService()
    private let userRepo = UserRepository()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.primary)
                        Text("Verify Your Identity")
                            .font(.system(size: 24, weight: .bold))
                        Text("We need a photo of your passport to confirm your identity. This is required once before your first rental.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                    // Passport image picker / preview
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .frame(height: 200)

                            if let image = passportImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Color.secondary)
                                    Text("Tap to add passport photo")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .onChange(of: selectedItem) { _, item in
                        loadImage(from: item)
                    }

                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        TipRow(icon: "checkmark.circle", text: "Make sure all text is clearly readable")
                        TipRow(icon: "checkmark.circle", text: "Flat, well-lit surface — no glare")
                        TipRow(icon: "checkmark.circle", text: "Include the full photo page")
                    }
                    .padding(.horizontal, 24)

                    if let error = uploadError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Identity Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(8)
                            .background(Color(.systemGray5), in: Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        Task { await uploadPassport() }
                    } label: {
                        HStack(spacing: 10) {
                            if isUploading {
                                ProgressView().tint(.white)
                            }
                            Text(isUploading ? "Uploading…" : "Submit for Verification")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(passportImage != nil && !isUploading ? Color.black : Color(.systemGray3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .disabled(passportImage == nil || isUploading)
                }
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - Load image from picker

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                passportImage = image
            }
        }
    }

    // MARK: - Upload

    private func uploadPassport() async {
        guard let uid = auth.currentUser?.uid,
              let image = passportImage else { return }

        isUploading = true
        uploadError = nil

        do {
            let url = try await storageService.uploadJPEG(
                image,
                path: "passports/\(uid).jpg"
            )
            try await userRepo.markPassportVerified(uid: uid, passportURL: url.absoluteString)
            dismiss()
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
        }
        isUploading = false
    }
}

// MARK: - Tip row

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.green)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.secondary)
        }
    }
}

#Preview {
    IdentityVerificationView()
        .environmentObject(AuthService())
}
