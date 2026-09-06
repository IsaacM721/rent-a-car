//
//  RentCheckoutView.swift
//  rent-a-car
//

import SwiftUI

struct RentCheckoutView: View {
    let car: Car
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vehicleStatusStore: VehicleStatusStore
    @EnvironmentObject private var authService: AuthService

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var selectedPayment: PaymentMethod = .none
    @State private var showAddCard = false
    @State private var showConfirmation = false
    @State private var isReserving = false
    @State private var reserveErrorMessage: String?
    @State private var showReserveError = false

    private let bookingRepository = BookingRepository()

    enum PaymentMethod {
        case none, card, dop
    }

    private var isCarAvailable: Bool { vehicleStatusStore.isAvailable(car) }

    private var rentalDays: Int {
        max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
    }

    private var dailyRate: Double {
        switch car.priceLevel {
        case "$":    return 30
        case "$$":   return 60
        case "$$$":  return 100
        default:     return 50
        }
    }

    private var subtotal: Double { dailyRate * Double(rentalDays) }
    private var serviceFee: Double { subtotal * 0.10 }
    private var total: Double { subtotal + serviceFee }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // Car summary
                    HStack(spacing: 14) {
                        CarLogoView(car: car, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(car.name)
                                .font(.system(size: 17, weight: .semibold))
                            Text("\(car.type) · \(car.neighborhood)")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(Int(dailyRate))/day")
                                .font(.system(size: 15, weight: .semibold))
                            Text(car.priceLevel)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground))

                    if !isCarAvailable {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("This car is currently in use by another renter and can't be booked right now.")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.primary)
                        }
                        .padding(16)
                        .background(Color.orange.opacity(0.12))
                    }

                    Divider()

                    // Dates
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Rental Dates")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .tracking(0.5)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        VStack(spacing: 0) {
                            DatePicker("Pick-up", selection: $startDate, displayedComponents: .date)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                            Divider().padding(.leading, 20)
                            DatePicker("Drop-off", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                        }
                        .background(Color(.systemBackground))

                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.secondary)
                            Text("\(rentalDays) day\(rentalDays == 1 ? "" : "s") total")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    Divider()

                    // Payment method
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Payment Method")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .tracking(0.5)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        VStack(spacing: 0) {
                            PaymentRow(
                                icon: "creditcard",
                                title: "Credit / Debit Card",
                                subtitle: "Add a card",
                                isSelected: selectedPayment == .card
                            ) {
                                selectedPayment = .card
                                showAddCard = true
                            }
                            Divider().padding(.leading, 58)
                            PaymentRow(
                                icon: "banknote",
                                title: "Pay with DOP",
                                subtitle: "Dominican peso balance",
                                isSelected: selectedPayment == .dop
                            ) {
                                selectedPayment = .dop
                            }
                        }
                        .background(Color(.systemBackground))
                        .padding(.bottom, 8)
                    }

                    Divider()

                    // Price breakdown
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Price Breakdown")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .tracking(0.5)
                            .padding(.top, 20)
                            .padding(.bottom, 14)

                        PriceRow(label: "$\(Int(dailyRate)) × \(rentalDays) day\(rentalDays == 1 ? "" : "s")", value: subtotal)
                        PriceRow(label: "Service fee (10%)", value: serviceFee)

                        Divider().padding(.vertical, 12)

                        HStack {
                            Text("Total")
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text("$\(String(format: "%.2f", total))")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                    .background(Color(.systemBackground))

                    Divider()

                    Spacer(minLength: 32)
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("Checkout")
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
                        reserve()
                    } label: {
                        HStack(spacing: 10) {
                            if isReserving { ProgressView().tint(.white) }
                            Text(isReserving ? "Reserving…" : "Reserve · $\(String(format: "%.2f", total))")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canReserve ? Color.black : Color(.systemGray3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .disabled(!canReserve)
                }
                .background(Color(.systemBackground))
            }
        }
        .sheet(isPresented: $showAddCard) {
            AddCardView()
        }
        .sheet(isPresented: $showConfirmation) {
            BookingConfirmationView(car: car, startDate: startDate, endDate: endDate, total: total)
        }
        .alert("Couldn't Reserve", isPresented: $showReserveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reserveErrorMessage ?? "Something went wrong.")
        }
    }

    // MARK: - Reservation

    private var canReserve: Bool {
        selectedPayment != .none && !isReserving && isCarAvailable
    }

    private func reserve() {
        guard canReserve else { return }
        isReserving = true

        Task {
            do {
                guard isCarAvailable else {
                    throw NSError(domain: "RentCheckoutView", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "This car was just marked in use. Please choose another car."
                    ])
                }

                let booking = BookingDoc(
                    docId: nil,
                    carId: car.id,
                    carName: car.name,
                    vehicleStatusKey: car.vehicleStatusKey,
                    dealerId: car.ownerId,
                    renterId: authService.currentUser?.uid ?? "",
                    startDate: startDate,
                    endDate: endDate,
                    total: total,
                    status: "active",
                    createdAt: nil
                )
                let bookingId = try await bookingRepository.createBooking(booking)
                try await vehicleStatusStore.setInUse(car, inUse: true, dealerId: car.ownerId, activeBookingId: bookingId)
                showConfirmation = true
            } catch {
                reserveErrorMessage = error.localizedDescription
                showReserveError = true
            }
            isReserving = false
        }
    }
}

// MARK: - Payment Row

struct PaymentRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.black : Color(.systemGray3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Price Row

struct PriceRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)
            Spacer()
            Text("$\(String(format: "%.2f", value))")
                .font(.system(size: 15))
        }
        .padding(.bottom, 10)
    }
}

// MARK: - Booking Confirmation View

struct BookingConfirmationView: View {
    let car: Car
    let startDate: Date
    let endDate: Date
    let total: Double
    @Environment(\.dismiss) private var dismiss

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 88, height: 88)
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Color.primary)
                    }

                    VStack(spacing: 8) {
                        Text("Booking Requested")
                            .font(.system(size: 24, weight: .bold))
                        Text("You'll hear back from the owner shortly.")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 0) {
                        ConfirmationRow(label: "Vehicle", value: car.name)
                        Divider().padding(.leading, 20)
                        ConfirmationRow(label: "Pick-up", value: dateFormatter.string(from: startDate))
                        Divider().padding(.leading, 20)
                        ConfirmationRow(label: "Drop-off", value: dateFormatter.string(from: endDate))
                        Divider().padding(.leading, 20)
                        ConfirmationRow(label: "Total", value: "$\(String(format: "%.2f", total))", bold: true)
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .background(Color(.systemGray6))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                    Button { dismiss() } label: {
                        Text("Done")
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
}

struct ConfirmationRow: View {
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

#Preview {
    RentCheckoutView(car: sampleCars[0])
        .environmentObject(VehicleStatusStore())
        .environmentObject(AuthService())
}
