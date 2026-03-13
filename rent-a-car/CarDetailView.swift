//
//  CarDetailView.swift
//  rent-a-car
//

import SwiftUI

struct CarDetailView: View {
    let car: Car
    @Environment(\.dismiss) private var dismiss
    @State private var isSaved = false
    @State private var showSchedule = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero
                    ZStack(alignment: .topLeading) {
                        CarHeroView(car: car, height: 280)

                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                    .padding(10)
                                    .background(.regularMaterial, in: Circle())
                            }
                            Spacer()
                            Button {} label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.primary)
                                    .padding(10)
                                    .background(.regularMaterial, in: Circle())
                            }
                        }
                        .padding(16)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        // Identity row
                        HStack(alignment: .top, spacing: 12) {
                            CarLogoView(car: car, size: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(car.name)
                                    .font(.system(size: 20, weight: .bold))
                                Text("\(car.type) / \(car.priceLevel) / \(car.neighborhood)")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.secondary)
                                HStack(spacing: 4) {
                                    Text(car.isAvailable ? "Available" : "Unavailable")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(car.isAvailable ? .green : .red)
                                    Text("•")
                                        .foregroundStyle(Color.secondary)
                                    Text(car.isAvailable ? "Pick up now" : "Available \(car.availableFrom)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.secondary)
                                }
                            }
                        }

                        // Action buttons
                        VStack(spacing: 10) {
                            HStack(spacing: 12) {
                                Button {
                                    isSaved.toggle()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Save")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.primary)
                                    .padding(.horizontal, 26)
                                    .padding(.vertical, 13)
                                    .overlay(Capsule().stroke(Color(.systemGray3), lineWidth: 1.5))
                                }

                                Button {} label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "location")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Get Directions")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.primary)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 13)
                                    .overlay(Capsule().stroke(Color(.systemGray3), lineWidth: 1.5))
                                }
                            }
                        }

                        // Description
                        Text(car.details)
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primary)
                            .lineSpacing(3)

                        Divider()

                        // Availability / schedule
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showSchedule.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "clock")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.primary)
                                    Text("Availability")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Color.primary)
                                    Spacer()
                                    Image(systemName: showSchedule ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.secondary)
                                }
                                .padding(.vertical, 4)
                            }

                            if showSchedule {
                                VStack(spacing: 0) {
                                    ForEach(car.schedule) { entry in
                                        HStack {
                                            Text(entry.day)
                                                .font(.system(size: 15))
                                                .foregroundStyle(entry.isToday ? Color.red : Color.secondary)
                                            Spacer()
                                            Text(entry.hours)
                                                .font(.system(size: 15))
                                                .foregroundStyle(entry.isToday ? Color.red : Color.primary)
                                        }
                                        .padding(.vertical, 5)
                                    }
                                }
                                .padding(.top, 10)
                            }
                        }

                        Divider()

                        // Address
                        Button {} label: {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.primary)
                                Text(car.address)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                            }
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    CarDetailView(car: sampleCars[1])
}
