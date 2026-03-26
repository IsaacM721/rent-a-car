//
//  AdminView.swift
//  rent-a-car
//

import SwiftUI
import UniformTypeIdentifiers

struct AdminView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var carsStore: CarsStore

    @State private var showAddForm = false
    @State private var editingCar: Car?
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var showImporter = false
    @State private var showImportConfirm = false
    @State private var importURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(carsStore.cars) { car in
                    Button {
                        editingCar = car
                    } label: {
                        HStack(spacing: 12) {
                            CarLogoView(car: car, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(car.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Text("\(car.type) · \(car.neighborhood)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Circle()
                                .fill(car.isAvailable ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteCars)
            }
            .listStyle(.plain)
            .navigationTitle("Manage Vehicles")
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            exportSeed()
                        } label: {
                            Label("Export Seed", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label("Import Seed", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.primary)
                    }

                    Button {
                        showAddForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddForm) {
            VehicleFormView()
        }
        .sheet(item: $editingCar) { car in
            VehicleFormView(car: car)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(url: url)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                importURL = url
                showImportConfirm = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .confirmationDialog(
            "Import will add all vehicles from the seed file.",
            isPresented: $showImportConfirm,
            titleVisibility: .visible
        ) {
            Button("Import") { performImport() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
    }

    private func deleteCars(at offsets: IndexSet) {
        for index in offsets {
            let car = carsStore.cars[index]
            if let id = car.docId {
                Task {
                    do {
                        try await carsStore.delete(id: id)
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }
        }
    }

    private func exportSeed() {
        errorMessage = "Seed export is disabled while using Firestore inventory."
        showError = true
    }

    private func performImport() {
        errorMessage = "Seed import is disabled while using Firestore inventory."
        showError = true
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
