import SwiftUI

/// Shown the first time a signed-in user opens "Manage Vehicles" without a dealer
/// profile yet. Collects the minimum needed to start listing cars, then hands off
/// to `AdminView`.
struct DealerOnboardingView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var dealerStore: DealerStore
    @Environment(\.dismiss) private var dismiss

    @State private var businessName = ""
    @State private var selectedZone: Zone = SantoDomingoZones.all[0]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var canContinue: Bool {
        !businessName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 72, height: 72)
                                Image(systemName: "key.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text("List Your Fleet")
                                .font(.system(size: 26, weight: .bold))
                            Text("Set up your dealer profile to start adding vehicles, setting your own prices, and marking cars available in real time.")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 40)
                        .padding(.bottom, 36)

                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Business Name")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                                    .tracking(0.5)
                                TextField("e.g. Mendez Rent-a-Car", text: $businessName)
                                    .font(.system(size: 17))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Primary Zone")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                                    .tracking(0.5)
                                Menu {
                                    ForEach(SantoDomingoZones.all) { zone in
                                        Button(zone.displayName) { selectedZone = zone }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedZone.displayName)
                                            .foregroundStyle(Color.primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.secondary)
                                    }
                                    .font(.system(size: 17))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }

                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                                Text("Verified with phone \(authService.currentUser?.phoneNumber ?? "")")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .padding(8)
                            .background(Color(.systemGray5), in: Circle())
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        Task { await save() }
                    } label: {
                        HStack(spacing: 10) {
                            if isSaving { ProgressView().tint(.white) }
                            Text(isSaving ? "Setting Up…" : "Start Listing Cars")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canContinue && !isSaving ? Color.black : Color(.systemGray3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .disabled(!canContinue || isSaving)
                }
                .background(Color(.systemBackground))
            }
            .alert("Couldn't Save Profile", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Something went wrong.")
            }
        }
    }

    private func save() async {
        guard let uid = authService.currentUser?.uid, canContinue else { return }
        isSaving = true
        do {
            try await dealerStore.completeOnboarding(
                uid: uid,
                businessName: businessName.trimmingCharacters(in: .whitespaces),
                phone: authService.currentUser?.phoneNumber ?? "",
                zoneId: selectedZone.id,
                zoneDisplayName: selectedZone.displayName
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isSaving = false
    }
}

#Preview {
    DealerOnboardingView()
        .environmentObject(AuthService())
        .environmentObject(DealerStore())
}
