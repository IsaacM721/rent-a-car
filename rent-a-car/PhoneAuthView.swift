import SwiftUI

/// Full-screen phone authentication flow shown before the main app.
/// Step 1: Enter phone number  →  Step 2: Enter 6-digit OTP
struct PhoneAuthView: View {
    @EnvironmentObject private var auth: AuthService

    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var step: Step = .phone
    @FocusState private var fieldFocused: Bool

    enum Step { case phone, otp }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Logo
                VStack(spacing: 6) {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 40, weight: .semibold))
                    Text("MOTORES.DO")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(2)
                }
                .padding(.top, 72)
                .padding(.bottom, 48)

                if step == .phone {
                    phoneStep
                } else {
                    otpStep
                }

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .alert("Error", isPresented: Binding(
            get: { auth.errorMessage != nil },
            set: { if !$0 { auth.clearError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.errorMessage ?? "")
        }
        .onAppear { fieldFocused = true }
    }

    // MARK: - Phone Step

    private var phoneStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Enter your phone number")
                    .font(.system(size: 24, weight: .bold))
                Text("We'll send a verification code via SMS.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
            }

            // Phone input
            HStack(spacing: 12) {
                // Country code pill
                Text("+1")
                    .font(.system(size: 17, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("(809) 000-0000", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.system(size: 17))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .focused($fieldFocused)
            }

            Button {
                Task {
                    let full = "+1\(phoneNumber.filter(\.isNumber))"
                    await auth.sendOTP(to: full)
                    if auth.errorMessage == nil {
                        step = .otp
                        fieldFocused = true
                    }
                }
            } label: {
                label(
                    title: "Send Code",
                    loading: auth.isLoading,
                    enabled: phoneNumber.filter(\.isNumber).count >= 10
                )
            }
            .disabled(phoneNumber.filter(\.isNumber).count < 10 || auth.isLoading)

            Button {
                Task { await auth.skipPhoneAuth() }
            } label: {
                Text("Skip for now")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .disabled(auth.isLoading)
        }
    }

    // MARK: - OTP Step

    private var otpStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Enter verification code")
                    .font(.system(size: 24, weight: .bold))
                Text("Sent to +1 \(phoneNumber). Check your messages.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondary)
            }

            // OTP input — single field, 6 digits
            TextField("6-digit code", text: $otpCode)
                .keyboardType(.numberPad)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .focused($fieldFocused)
                .onChange(of: otpCode) { _, new in
                    // Limit to 6 digits
                    let digits = new.filter(\.isNumber)
                    if digits.count > 6 { otpCode = String(digits.prefix(6)) }
                    else { otpCode = digits }
                }

            Button {
                Task { await auth.verifyOTP(otpCode) }
            } label: {
                label(
                    title: "Verify",
                    loading: auth.isLoading,
                    enabled: otpCode.count == 6
                )
            }
            .disabled(otpCode.count < 6 || auth.isLoading)

            // Back / resend
            HStack(spacing: 4) {
                Button {
                    step = .phone
                    otpCode = ""
                    fieldFocused = true
                } label: {
                    Text("Change number")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary)
                }

                Text("·")
                    .foregroundStyle(Color.secondary)

                Button {
                    Task {
                        let full = "+1\(phoneNumber.filter(\.isNumber))"
                        await auth.sendOTP(to: full)
                    }
                } label: {
                    Text("Resend code")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.primary)
                }
            }
        }
    }

    // MARK: - Shared button label

    private func label(title: String, loading: Bool, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            if loading {
                ProgressView()
                    .tint(.white)
            }
            Text(title)
                .font(.system(size: 17, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(enabled ? Color.black : Color(.systemGray3))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    PhoneAuthView()
        .environmentObject(AuthService())
}
