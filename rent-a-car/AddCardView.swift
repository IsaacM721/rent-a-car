//
//  AddCardView.swift
//  rent-a-car
//

import SwiftUI

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var cardNumber = ""
    @State private var cardHolder = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var isCVVFocused = false

    private var formattedCardNumber: String {
        let digits = cardNumber.filter(\.isNumber)
        var result = ""
        for (i, char) in digits.prefix(16).enumerated() {
            if i > 0 && i % 4 == 0 { result += " " }
            result.append(char)
        }
        return result
    }

    private var cardBrand: String {
        let digits = cardNumber.filter(\.isNumber)
        if digits.hasPrefix("4") { return "visa" }
        if digits.hasPrefix("5") || digits.hasPrefix("2") { return "mastercard" }
        if digits.hasPrefix("3") { return "amex" }
        return "creditcard"
    }

    private var isComplete: Bool {
        cardNumber.filter(\.isNumber).count >= 15 &&
        !cardHolder.trimmingCharacters(in: .whitespaces).isEmpty &&
        expiry.filter(\.isNumber).count == 4 &&
        cvv.filter(\.isNumber).count >= 3
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Card preview
                    CardPreviewView(
                        cardNumber: cardNumber.filter(\.isNumber),
                        cardHolder: cardHolder,
                        expiry: expiry,
                        brand: cardBrand,
                        flipped: isCVVFocused
                    )
                    .padding(.top, 8)

                    // Form
                    VStack(spacing: 0) {
                        CardField(
                            label: "Card Number",
                            placeholder: "0000 0000 0000 0000",
                            text: Binding(
                                get: { formattedCardNumber },
                                set: { cardNumber = $0 }
                            ),
                            keyboardType: .numberPad
                        )
                        Divider().padding(.leading, 20)
                        CardField(
                            label: "Cardholder Name",
                            placeholder: "Name on card",
                            text: $cardHolder,
                            keyboardType: .default
                        )
                        Divider().padding(.leading, 20)
                        HStack(spacing: 0) {
                            CardField(
                                label: "Expiry",
                                placeholder: "MM / YY",
                                text: Binding(
                                    get: { formatExpiry(expiry) },
                                    set: { expiry = $0 }
                                ),
                                keyboardType: .numberPad
                            )
                            Divider()
                                .frame(height: 54)
                            CardField(
                                label: "CVV",
                                placeholder: "•••",
                                text: $cvv,
                                keyboardType: .numberPad,
                                isSecure: true,
                                onFocus: { focused in isCVVFocused = focused }
                            )
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    // Security note
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                        Text("Your card details are encrypted and secure.")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 32)
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("Add Card")
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
                        dismiss()
                    } label: {
                        Text("Save Card")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isComplete ? Color.black : Color(.systemGray3))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    .disabled(!isComplete)
                }
                .background(Color(.systemBackground))
            }
        }
    }

    private func formatExpiry(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        if digits.count <= 2 { return digits }
        return "\(digits.prefix(2)) / \(digits.dropFirst(2).prefix(2))"
    }
}

// MARK: - Card Preview

struct CardPreviewView: View {
    let cardNumber: String
    let cardHolder: String
    let expiry: String
    let brand: String
    var flipped: Bool

    private var displayNumber: String {
        let padded = cardNumber.padding(toLength: 16, withPad: "0", startingAt: 0)
        let chars = Array(padded)
        return stride(from: 0, to: 16, by: 4).map {
            String(chars[$0..<min($0 + 4, chars.count)])
        }.joined(separator: "  ")
    }

    private func index(_ s: String, _ i: Int, _ j: Int) -> String {
        let arr = Array(s)
        guard i < arr.count else { return "" }
        return String(arr[i..<min(j, arr.count)])
    }

    var body: some View {
        ZStack {
            // Front
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.12), Color(white: 0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "steeringwheel")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                        Spacer()
                        Image(systemName: brand == "creditcard" ? "creditcard" : (brand == "visa" ? "creditcard.fill" : "creditcard.fill"))
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                    Spacer()

                    Text(cardNumber.isEmpty ? "0000  0000  0000  0000" : displayNumber)
                        .font(.system(size: 19, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .tracking(1)
                        .padding(.horizontal, 22)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("CARDHOLDER")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .tracking(1)
                            Text(cardHolder.isEmpty ? "YOUR NAME" : cardHolder.uppercased())
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("EXPIRES")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .tracking(1)
                            Text(expiry.filter(\.isNumber).isEmpty ? "MM/YY" : formatDisplayExpiry(expiry))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 22)
                }
            }
            .opacity(flipped ? 0 : 1)
            .rotation3DEffect(.degrees(flipped ? 90 : 0), axis: (0, 1, 0))

            // Back (CVV side)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.18), Color(white: 0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(white: 0.05))
                        .frame(height: 48)
                        .padding(.top, 30)

                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white)
                                .frame(width: 120, height: 38)
                            Text("CVV")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(white: 0.2))
                        }
                        .padding(.trailing, 22)
                    }
                    .padding(.top, 16)

                    Spacer()
                }
            }
            .opacity(flipped ? 1 : 0)
            .rotation3DEffect(.degrees(flipped ? 0 : -90), axis: (0, 1, 0))
        }
        .frame(height: 200)
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.3), value: flipped)
    }

    private func formatDisplayExpiry(_ raw: String) -> String {
        let d = raw.filter(\.isNumber)
        if d.count < 3 { return String(d.prefix(2)) }
        return "\(d.prefix(2))/\(d.dropFirst(2).prefix(2))"
    }
}

// MARK: - Card Field

struct CardField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var onFocus: ((Bool) -> Void)? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.secondary)
                .tracking(0.3)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .onChange(of: isFocused) { _, focused in onFocus?(focused) }
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .onChange(of: isFocused) { _, focused in onFocus?(focused) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }
}

#Preview {
    AddCardView()
}
