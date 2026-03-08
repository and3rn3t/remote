//
//  SettingsView.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import SwiftUI
import SwiftData

// MARK: - App-level Settings (UserDefaults-backed)

enum AppSettings {
    @AppStorage("autoConnectLastReceiver") static var autoConnectLastReceiver = false
    @AppStorage("lastConnectedReceiverID") static var lastConnectedReceiverID: String = ""
    @AppStorage("hasCompletedOnboarding") static var hasCompletedOnboarding = false
}

// MARK: - Receiver Settings View

struct ReceiverSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var receiver: DenonReceiver
    var api: DenonAPI?

    @State private var editedName: String = ""
    @State private var editedIP: String = ""
    @State private var editedPort: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $editedName)
                        .textContentType(.name)

                    TextField("IP Address", text: $editedIP)
                        .textContentType(.none)
                        .keyboardType(.decimalPad)
                        .autocorrectionDisabled()

                    TextField("Port", text: $editedPort)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Receiver Details")
                }

                Section {
                    Toggle("Favorite", isOn: $receiver.isFavorite)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Volume Limit")
                            Spacer()
                            Text("\(receiver.volumeLimit) dB")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(receiver.volumeLimit) },
                                set: { receiver.volumeLimit = Int($0) }
                            ),
                            in: 10...98,
                            step: 1
                        )
                        .accessibilityLabel("Volume Limit")
                        .accessibilityValue("\(receiver.volumeLimit) decibels")

                        Text("Prevents volume from exceeding this level.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Preferences")
                }

                Section {
                    if let lastConnected = receiver.lastConnected {
                        LabeledContent("Last Connected") {
                            Text(lastConnected, format: .relative(presentation: .named))
                        }
                    }
                    LabeledContent("Receiver ID") {
                        Text(receiver.id.uuidString.prefix(8) + "…")
                            .foregroundStyle(.secondary)
                            .font(.caption.monospaced())
                    }
                } header: {
                    Text("Info")
                }

                if let api {
                    Section {
                        LabeledContent("Model") {
                            Text(api.state.receiverModel.isEmpty ? "Not available" : api.state.receiverModel)
                                .foregroundStyle(api.state.receiverModel.isEmpty ? .secondary : .primary)
                        }
                        LabeledContent("Firmware") {
                            Text(api.state.firmwareVersion.isEmpty ? "Not available" : api.state.firmwareVersion)
                                .foregroundStyle(api.state.firmwareVersion.isEmpty ? .secondary : .primary)
                        }
                    } header: {
                        Text("Receiver Info")
                    }
                }
            }
            .navigationTitle("Receiver Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(editedName.isEmpty || editedIP.isEmpty)
                }
            }
            .onAppear {
                editedName = receiver.name
                editedIP = receiver.ipAddress
                editedPort = String(receiver.port)
                if let api, api.isConnected {
                    Task { try? await api.queryReceiverInfo() }
                }
            }
        }
    }

    private func saveChanges() {
        receiver.name = editedName
        receiver.ipAddress = editedIP
        receiver.port = Int(editedPort) ?? 23
        dismiss()
    }
}

// MARK: - App Settings View

struct AppSettingsView: View {
    @AppStorage("autoConnectLastReceiver") private var autoConnectLastReceiver = false
    @State private var showingLogViewer = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Auto-connect on launch", isOn: $autoConnectLastReceiver)
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Automatically connect to the last-used receiver when the app opens.")
                }

                Section {
                    Button {
                        showingLogViewer = true
                    } label: {
                        HStack {
                            Label("Connection Log", systemImage: "doc.text")
                            Spacer()
                            Text("\(ConnectionLogger.shared.entries.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Diagnostics")
                }

                Section {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer()
                        Text("Enabled")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Receivers and scenes sync automatically across your devices via iCloud.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("App Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingLogViewer) {
                LogViewerView()
            }
        }
    }
}
