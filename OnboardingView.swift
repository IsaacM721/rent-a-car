import FirebaseAuth
import PhotosUI
import SwiftUI

// MARK: - OnboardingView
// Shown once after the user logs in for the first time.
// Steps: Profile photo → Vehicle type → Pick dates → Confirm + pricing → Receipt
struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthService
    /// Called when the user finishes or skips onboarding
    let onComplete: () -> Void

    @State private var step: OnboardingStep = .profile

    enum OnboardingStep: Int, CaseIterable {
        case profile = 0
        case vehicleType = 1
        case dates = 2
        case confirm = 3
        case receipt = 4
    }

    // Shared state passed between steps
    @State private var selectedVehicleTypes: Set<String> = []
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            switch step {
            case .profile:
                OnboardingProfileStep(
                    onNext: { withAnimation { step = .vehicleType } },
                    onSkip: { withAnimation { step = .vehicleType } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .vehicleType:
                OnboardingVehicleTypeStep(
                    selected: $selectedVehicleTypes,
                    onNext: { withAnimation { step = .dates } },
                    onSkip: { onComplete() }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .dates:
                OnboardingDatesStep(
                    startDate: $startDate,
                    endDate: $endDate,
                    onNext: { withAnimation { step = .confirm } },
                    onBack: { withAnimation { step = .vehicleType } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .confirm:
                OnboardingConfirmStep(
                    selectedVehicleTypes: selectedVehicleTypes,
                    startDate: startDate,
                    endDate: endDate,
                    onNext: { withAnimation { step = .receipt } },
                    onBack: { withAnimation { step = .dates } }
                )
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

            case .receipt:
                OnboardingReceiptStep(onDone: { onComplete() })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        // Progress dots + skip button at the top
        .overlay(alignment: .top) {
            if step != .receipt {
                HStack {
                    OnboardingProgressDots(current: step.rawValue, total: OnboardingStep.allCases.count - 1)
                    Spacer()
                    Button("Skip") {
                        onComplete()
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
                    .padding(.trailing, 24)
                }
                .padding(.top, 60)
                .padding(.leading, 24)
            }
        }
    }
}

// MARK: - Progress Dots

private struct OnboardingProgressDots: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.primary : Color(.systemGray4))
                    .frame(width: i == current ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }
}

// MARK: - Step 1: Profile Photo

private struct OnboardingProfileStep: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject private var auth: AuthService
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isUploading = false
    @State private var uploadError: String?

    private let storageService = StorageService()
    private let userRepo = UserRepository()

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 110)

            VStack(spacing: 28) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.primary)
                    Text("Complete your profile")
                        .font(.system(size: 26, weight: .bold))
                    Text("Add a passport or ID photo so owners can verify you before handing over the keys.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Photo picker
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                            .frame(height: 180)

                        if let image = profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 34))
                                    .foregroundStyle(Color.secondary)
                                Text("Tap to add ID / passport photo")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                    }
                }
                .onChange(of: selectedItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            profileImage = image
                        }
                    }
                }

                // Tips
                VStack(alignment: .leading, spacing: 10) {
                    OnboardingTip(icon: "checkmark.circle.fill", text: "All text must be clearly readable")
                    OnboardingTip(icon: "checkmark.circle.fill", text: "Flat surface, no glare")
                    OnboardingTip(icon: "checkmark.circle.fill", text: "Include the full photo page")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let error = uploadError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            // Bottom buttons
            VStack(spacing: 12) {
                Divider()
                Button {
                    if profileImage != nil {
                        Task { await uploadAndContinue() }
                    } else {
                        onNext()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isUploading { ProgressView().tint(.white) }
                        Text(isUploading ? "Uploading…" : (profileImage != nil ? "Save & Continue" : "Continue"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 20)
                }
                .disabled(isUploading)

                Button(action: onSkip) {
                    Text("Skip for now")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
    }

    private func uploadAndContinue() async {
        guard let uid = auth.currentUser?.uid,
              let image = profileImage else {
            onNext(); return
        }
        isUploading = true
        uploadError = nil
        do {
            let url = try await storageService.uploadJPEG(image, path: "passports/\(uid).jpg")
            try await userRepo.markPassportVerified(uid: uid, passportURL: url.absoluteString)
            onNext()
        } catch {
            uploadError = "Upload failed: \(error.localizedDescription)"
        }
        isUploading = false
    }
}

// MARK: - Step 2: Vehicle Type

private struct OnboardingVehicleTypeStep: View {
    @Binding var selected: Set<String>
    let onNext: () -> Void
    let onSkip: () -> Void

    private let types: [(icon: String, label: String)] = [
        ("car",              "Sedan"),
        ("car.side",         "SUV"),
        ("truck.box",        "Truck"),
        ("van.front",        "Van"),
        ("bolt.car",         "Electric"),
        ("car.2",            "Luxury"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 110)

            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "car.rear.and.tire.marks")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.primary)
                    Text("What do you need?")
                        .font(.system(size: 26, weight: .bold))
                    Text("Pick the vehicle types you're interested in. You can always change this later.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Grid of type tiles
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(types, id: \.label) { type in
                        let isSelected = selected.contains(type.label)
                        Button {
                            if isSelected {
                                selected.remove(type.label)
                            } else {
                                selected.insert(type.label)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 26))
                                Text(type.label)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(isSelected ? .white : Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(isSelected ? Color.black : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .animation(.spring(response: 0.25), value: isSelected)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Divider()
                Button(action: onNext) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                }

                Button(action: onSkip) {
                    Text("Skip to app")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Step 3: Pick Dates

private struct OnboardingDatesStep: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onNext: () -> Void
    let onBack: () -> Void

    private var rentalDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 110)

            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.primary)
                    Text("When do you need it?")
                        .font(.system(size: 26, weight: .bold))
                    Text("Select your pickup and drop-off dates.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 0) {
                    DatePicker("Pick-up", selection: $startDate, in: Date()..., displayedComponents: .date)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    Divider().padding(.leading, 20)
                    DatePicker("Drop-off", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                    Text("\(rentalDays) day\(rentalDays == 1 ? "" : "s") selected")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Divider()
                Button(action: onNext) {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                }

                Button(action: onBack) {
                    Text("Back")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Step 4: Confirm + Pricing

private struct OnboardingConfirmStep: View {
    let selectedVehicleTypes: Set<String>
    let startDate: Date
    let endDate: Date
    let onNext: () -> Void
    let onBack: () -> Void

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private var rentalDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }

    // Estimated price range based on selected types
    private var priceRange: String {
        if selectedVehicleTypes.contains("Luxury") || selectedVehicleTypes.contains("SUV") {
            return "$60 – $100 / day"
        } else if selectedVehicleTypes.contains("Truck") || selectedVehicleTypes.contains("Van") {
            return "$50 – $80 / day"
        } else {
            return "$30 – $60 / day"
        }
    }

    private var estimatedTotal: String {
        let low: Double
        let high: Double
        if selectedVehicleTypes.contains("Luxury") || selectedVehicleTypes.contains("SUV") {
            low = 60; high = 100
        } else if selectedVehicleTypes.contains("Truck") || selectedVehicleTypes.contains("Van") {
            low = 50; high = 80
        } else {
            low = 30; high = 60
        }
        let days = Double(rentalDays)
        let lowTotal = low * days * 1.10
        let highTotal = high * days * 1.10
        return "$\(Int(lowTotal)) – $\(Int(highTotal))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 110)

            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.primary)
                    Text("Looks good!")
                        .font(.system(size: 26, weight: .bold))
                    Text("Here's a summary of your preferences. You'll pick the exact car in the app.")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 0) {
                    OnboardingSummaryRow(label: "Vehicle types", value: selectedVehicleTypes.isEmpty ? "Any" : selectedVehicleTypes.sorted().joined(separator: ", "))
                    Divider().padding(.leading, 20)
                    OnboardingSummaryRow(label: "Pick-up", value: dateFormatter.string(from: startDate))
                    Divider().padding(.leading, 20)
                    OnboardingSummaryRow(label: "Drop-off", value: dateFormatter.string(from: endDate))
                    Divider().padding(.leading, 20)
                    OnboardingSummaryRow(label: "Duration", value: "\(rentalDays) day\(rentalDays == 1 ? "" : "s")")
                    Divider().padding(.leading, 20)
                    OnboardingSummaryRow(label: "Est. daily rate", value: priceRange)
                    Divider().padding(.leading, 20)
                    OnboardingSummaryRow(label: "Est. total (incl. fees)", value: estimatedTotal, bold: true)
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text("Prices shown are estimates. Final price depends on the vehicle you choose.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Divider()
                Button(action: onNext) {
                    Text("Confirm")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                }

                Button(action: onBack) {
                    Text("Back")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Step 5: Receipt / Waiting

private struct OnboardingReceiptStep: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Success icon
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 100, height: 100)
                    Image(systemName: "car.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.primary)
                }

                VStack(spacing: 12) {
                    Text("You're all set!")
                        .font(.system(size: 28, weight: .bold))
                    Text("Browse available cars on the map and tap any car to book it. Your receipt will appear in your Wallet once a booking is confirmed.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                // What happens next
                VStack(spacing: 0) {
                    OnboardingNextRow(number: "1", text: "Browse cars on the map")
                    Divider().padding(.leading, 52)
                    OnboardingNextRow(number: "2", text: "Pick dates and confirm your booking")
                    Divider().padding(.leading, 52)
                    OnboardingNextRow(number: "3", text: "Wait for the owner to approve")
                    Divider().padding(.leading, 52)
                    OnboardingNextRow(number: "4", text: "Pick up your vehicle — enjoy the ride!")
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 0) {
                Divider()
                Button(action: onDone) {
                    Text("Start browsing")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
            }
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Shared small components

private struct OnboardingTip: View {
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

private struct OnboardingSummaryRow: View {
    let label: String
    let value: String
    var bold: Bool = false
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: bold ? .bold : .regular))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct OnboardingNextRow: View {
    let number: String
    let text: String
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 28, height: 28)
                Text(number)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(.systemBackground))
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(AuthService())
}
