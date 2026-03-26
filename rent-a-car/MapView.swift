//
//  MapView.swift
//  rent-a-car
//

import SwiftUI
import MapKit

enum MapTab {
    case map, forYou
}

struct MapView: View {
    @EnvironmentObject private var carsStore: CarsStore
    @State private var selectedCar: Car?
    @State private var activeTab: MapTab = .map
    @State private var showPayWithDOP = false
    @State private var showCarDetail = false
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 18.4861, longitude: -69.9312),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        )
    )

    var body: some View {
        ZStack(alignment: .top) {
            // Map
            Map(position: $cameraPosition) {
                ForEach(carsStore.cars) { car in
                    Annotation("", coordinate: car.coordinate) {
                        Button {
                            selectedCar = car
                            showCarDetail = true
                        } label: {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 2)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            // Top overlay
            VStack(spacing: 0) {
                HStack {
                    // Profile button
                    Button {} label: {
                        Image(systemName: "person")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.primary)
                            .padding(10)
                            .background(.regularMaterial, in: Circle())
                    }

                    Spacer()

                    // Map / For You tabs
                    HStack(spacing: 0) {
                        Button { activeTab = .map } label: {
                            Text("Map")
                                .font(.system(size: 15, weight: activeTab == .map ? .semibold : .regular))
                                .foregroundStyle(activeTab == .map ? Color.primary : Color.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                        }
                        .overlay(alignment: .bottom) {
                            if activeTab == .map {
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundStyle(Color.primary)
                                    .padding(.horizontal, 16)
                            }
                        }
                        Button { activeTab = .forYou } label: {
                            Text("For You")
                                .font(.system(size: 15, weight: activeTab == .forYou ? .semibold : .regular))
                                .foregroundStyle(activeTab == .forYou ? Color.primary : Color.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                        }
                        .overlay(alignment: .bottom) {
                            if activeTab == .forYou {
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundStyle(Color.primary)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(.regularMaterial, in: Capsule())

                    Spacer()

                    // Search button
                    Button {} label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.primary)
                            .padding(10)
                            .background(.regularMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Pay with DOP pill
                Button { showPayWithDOP = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "banknote")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Pay with DOP")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.black)
                    .clipShape(Capsule())
                }
                .padding(.top, 10)

                Spacer()

                // Bottom location + car card area
                VStack(spacing: 8) {
                    HStack {
                        Button {} label: {
                            HStack(spacing: 4) {
                                Text("Santo Domingo")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.regularMaterial, in: Capsule())
                        }

                        Spacer()

                        Button {} label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.primary)
                                .padding(10)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 16)

                    // Selected car card
                    if let car = selectedCar {
                        MapCarCard(car: car)
                            .padding(.horizontal, 16)
                            .onTapGesture { showCarDetail = true }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            if selectedCar == nil { selectedCar = carsStore.cars.first }
        }
        .onChange(of: carsStore.cars) { _, new in
            if selectedCar == nil { selectedCar = new.first }
        }
        .sheet(isPresented: $showPayWithDOP) {
            PayWithDOPView()
        }
        .sheet(isPresented: $showCarDetail) {
            if let car = selectedCar {
                CarDetailView(car: car)
            }
        }
    }
}

struct MapCarCard: View {
    let car: Car

    var body: some View {
        VStack(spacing: 0) {
            CarHeroView(car: car, height: 110)
                .overlay(alignment: .topTrailing) {
                    Button {} label: {
                        Image(systemName: "bookmark")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primary)
                            .padding(8)
                            .background(.regularMaterial, in: Circle())
                    }
                    .padding(10)
                }

            // Info row
            HStack(spacing: 10) {
                CarLogoView(car: car, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(car.name)
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(car.type) / \(car.priceLevel) / \(car.neighborhood)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                    HStack(spacing: 4) {
                        Text(car.isAvailable ? "Available" : "Unavailable")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(car.isAvailable ? .green : .red)
                        Text("•")
                            .foregroundStyle(Color.secondary)
                            .font(.system(size: 13))
                        Text(car.isAvailable ? "Pick up now" : "Available \(car.availableFrom)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondary)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }
}

#Preview {
    MapView()
}
