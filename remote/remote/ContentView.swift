//
//  ContentView.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \DenonReceiver.lastConnected, order: .reverse) private var receivers: [DenonReceiver]

    @State private var showingAddReceiver = false
    @State private var showingAppSettings = false
    @State private var selectedReceiver: DenonReceiver?
    @State private var showFavoritesOnly = false
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    private var filteredReceivers: [DenonReceiver] {
        var result = receivers
        if showFavoritesOnly {
            result = result.filter(\.isFavorite)
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.ipAddress.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            receiversList
        } detail: {
            if let receiver = selectedReceiver {
                ReceiverControlView(receiver: receiver)
            } else {
                emptyDetailView
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Receivers List

    private var receiversList: some View {
        List(selection: $selectedReceiver) {
            Section {
                ForEach(filteredReceivers) { receiver in
                    ReceiverRowView(receiver: receiver)
                        .tag(receiver)
                }
                .onDelete(perform: deleteReceivers)
            } header: {
                if showFavoritesOnly {
                    Text("Favorites")
                } else {
                    Text("My Receivers")
                }
            }
        }
        .navigationTitle("Denon Remote")
        .toolbar(id: "main-toolbar") {
            ToolbarItem(id: "add", placement: .primaryAction) {
                Button {
                    showingAddReceiver = true
                } label: {
                    Label("Add Receiver", systemImage: "plus")
                }
            }

            ToolbarItem(id: "filter", placement: .primaryAction) {
                Button {
                    withAnimation { showFavoritesOnly.toggle() }
                } label: {
                    Label("Favorites", systemImage: showFavoritesOnly ? "star.fill" : "star")
                }
                .accessibilityLabel(showFavoritesOnly ? "Show all receivers" : "Show favorites only")
            }

            ToolbarItem(id: "settings", placement: .navigationBarLeading) {
                Button {
                    showingAppSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }

            ToolbarItem(id: "edit", placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .searchable(text: $searchText, prompt: "Search receivers")
        .sheet(isPresented: $showingAddReceiver) {
            AddReceiverView()
        }
        .sheet(isPresented: $showingAppSettings) {
            AppSettingsView()
        }
        .onAppear {
            autoConnectIfNeeded()
        }
        .background {
            // iPad keyboard shortcuts
            Button("") { showingAddReceiver = true }
                .keyboardShortcut("n", modifiers: .command)
                .hidden()
            Button("") { showingAppSettings = true }
                .keyboardShortcut(",", modifiers: .command)
                .hidden()
        }
    }

    private var emptyDetailView: some View {
        ContentUnavailableView {
            Label("No Receiver Selected", systemImage: "hifispeaker.2")
        } description: {
            Text("Select a receiver from the list or add a new one")
        } actions: {
            Button {
                showingAddReceiver = true
            } label: {
                Text("Add Receiver")
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - Actions

    private func deleteReceivers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredReceivers[index])
            }
        }
    }

    private func autoConnectIfNeeded() {
        guard AppSettings.autoConnectLastReceiver,
              !AppSettings.lastConnectedReceiverID.isEmpty,
              let lastID = UUID(uuidString: AppSettings.lastConnectedReceiverID),
              let receiver = receivers.first(where: { $0.id == lastID }) else {
            return
        }
        selectedReceiver = receiver
    }
}

// MARK: - Receiver Row View

struct ReceiverRowView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let receiver: DenonReceiver

    var body: some View {
        HStack {
            Image(systemName: receiver.isFavorite ? "star.fill" : "hifispeaker.2")
                .foregroundStyle(receiver.isFavorite ? .yellow : .secondary)
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(receiver.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(receiver.ipAddress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if horizontalSizeClass == .regular {
                        Text("Port \(receiver.port)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let lastConnected = receiver.lastConnected {
                    Text("Last connected \(lastConnected, format: .relative(presentation: .named))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if horizontalSizeClass == .regular {
                Spacer()
                Text("Vol limit: \(receiver.volumeLimit)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(receiverAccessibilityLabel)
    }

    private var receiverAccessibilityLabel: String {
        var parts = [receiver.name, receiver.ipAddress]
        if receiver.isFavorite { parts.append("Favorite") }
        if let lastConnected = receiver.lastConnected {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            parts.append("Last connected \(formatter.localizedString(for: lastConnected, relativeTo: Date()))")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Add Receiver View

struct AddReceiverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingReceivers: [DenonReceiver]

    @State private var name = ""
    @State private var ipAddress = ""
    @State private var port = "23"
    @State private var discovery = BonjourDiscovery()

    private var ipValidationError: String? {
        guard !ipAddress.isEmpty else { return nil }
        let parts = ipAddress.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return "IP address must have 4 octets (e.g. 192.168.1.100)" }
        for part in parts {
            guard let num = Int(part), (0...255).contains(num) else {
                return "Each octet must be a number between 0 and 255"
            }
        }
        return nil
    }

    private var portValidationError: String? {
        guard !port.isEmpty else { return nil }
        guard let portNum = Int(port), (1...65535).contains(portNum) else {
            return "Port must be between 1 and 65535"
        }
        return nil
    }

    private var duplicateError: String? {
        guard !ipAddress.isEmpty else { return nil }
        let portValue = Int(port) ?? 23
        let isDuplicate = existingReceivers.contains { $0.ipAddress == ipAddress && $0.port == portValue }
        return isDuplicate ? "A receiver with this IP and port already exists" : nil
    }

    private var isFormValid: Bool {
        !name.isEmpty && !ipAddress.isEmpty && ipValidationError == nil
            && portValidationError == nil && duplicateError == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Auto-Discovery Section
                Section {
                    if discovery.isScanning {
                        HStack {
                            ProgressView()
                            Text("Scanning network…")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            discovery.startScan()
                        } label: {
                            Label("Scan for Receivers", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }

                    if let error = discovery.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    ForEach(discovery.discoveredReceivers) { discovered in
                        Button {
                            addDiscoveredReceiver(discovered)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(discovered.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(discovered.host)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                            }
                        }
                        .accessibilityLabel("Add \(discovered.name) at \(discovered.host)")
                    }
                } header: {
                    Text("Auto-Discovery")
                } footer: {
                    if discovery.discoveredReceivers.isEmpty && !discovery.isScanning {
                        Text("Tap Scan to find Denon receivers on your network, or add one manually below.")
                    }
                }

                // MARK: - Manual Entry Section
                Section {
                    TextField("Name", text: $name)
                        .textContentType(.name)

                    TextField("IP Address", text: $ipAddress)
                        .textContentType(.none)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()

                    if let error = ipValidationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)

                    if let error = portValidationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let error = duplicateError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Manual Entry")
                } footer: {
                    Text("Enter your Denon AVR's IP address. You can find this in your receiver's network settings. Default port is 23.")
                }
            }
            .navigationTitle("Add Receiver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        discovery.stopScan()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addReceiver()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onDisappear {
                discovery.stopScan()
            }
        }
    }

    private func addReceiver() {
        guard isFormValid else { return }
        withAnimation {
            let portValue = Int(port) ?? 23
            let receiver = DenonReceiver(name: name, ipAddress: ipAddress, port: portValue)
            modelContext.insert(receiver)
            dismiss()
        }
    }

    private func addDiscoveredReceiver(_ discovered: DiscoveredReceiver) {
        // Check for duplicates before adding
        let isDuplicate = existingReceivers.contains {
            $0.ipAddress == discovered.host && $0.port == DenonConstants.defaultPort
        }
        guard !isDuplicate else { return }

        withAnimation {
            let receiver = DenonReceiver(
                name: discovered.name,
                ipAddress: discovered.host,
                port: DenonConstants.defaultPort
            )
            modelContext.insert(receiver)
            dismiss()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: DenonReceiver.self, inMemory: true)
}
