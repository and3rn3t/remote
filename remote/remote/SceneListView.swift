//
//  SceneListView.swift
//  remote
//
//  Created by Matt on 3/8/26.
//

import SwiftUI
import SwiftData

// MARK: - Scene List View

struct SceneListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allScenes: [ReceiverScene]

    let receiverID: UUID
    let api: DenonAPI
    let receiver: DenonReceiver

    private var scenes: [ReceiverScene] {
        allScenes
            .filter { $0.receiverID == receiverID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @State private var showingSaveSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if scenes.isEmpty {
                    ContentUnavailableView {
                        Label("No Scenes", systemImage: "theatermasks")
                    } description: {
                        Text("Save the current receiver configuration as a scene to quickly recall it later.")
                    } actions: {
                        Button("Save Current Scene") {
                            showingSaveSheet = true
                        }
                        .buttonStyle(.glass)
                    }
                } else {
                    List {
                        Section {
                            ForEach(scenes) { scene in
                                SceneRowView(scene: scene) {
                                    recallScene(scene)
                                }
                            }
                            .onDelete(perform: deleteScenes)
                        } header: {
                            Text("Saved Scenes")
                        }
                    }
                }
            }
            .navigationTitle("Scenes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSaveSheet = true
                    } label: {
                        Label("Save Scene", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                SaveSceneView(
                    receiverID: receiverID,
                    api: api,
                    receiver: receiver
                )
            }
        }
    }

    private func deleteScenes(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(scenes[index])
        }
    }

    private func recallScene(_ scene: ReceiverScene) {
        Task {
            do {
                // Main zone
                try await api.setInput(scene.inputCode)
                try await api.setVolume(scene.volume)
                try await api.setSurroundMode(scene.surroundMode)
                try await api.setMute(scene.isMuted)

                // Zone 2
                if let input = scene.zone2InputCode {
                    try await api.setZone2Input(input)
                }
                if let vol = scene.zone2Volume {
                    try await api.setZone2Volume(vol)
                }
                if let muted = scene.zone2IsMuted {
                    try await api.setZone2Mute(muted)
                }

                // Zone 3
                if let input = scene.zone3InputCode {
                    try await api.setZone3Input(input)
                }
                if let vol = scene.zone3Volume {
                    try await api.setZone3Volume(vol)
                }
                if let muted = scene.zone3IsMuted {
                    try await api.setZone3Mute(muted)
                }
            } catch {
                api.errorMessage = error.localizedDescription
            }
        }
        dismiss()
    }
}

// MARK: - Scene Row View

struct SceneRowView: View {
    let scene: ReceiverScene
    let onRecall: () -> Void

    var body: some View {
        Button(action: onRecall) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Label(inputName(for: scene.inputCode), systemImage: "arrow.right.circle")
                        Text("Vol \(scene.volume)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        if scene.hasZone2 { zoneTag("Z2") }
                        if scene.hasZone3 { zoneTag("Z3") }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    Text(scene.createdAt, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityLabel("Recall scene \(scene.name)")
        .accessibilityHint("Input \(inputName(for: scene.inputCode)), volume \(scene.volume)")
    }

    private func zoneTag(_ label: String) -> some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: .capsule)
    }

    private func inputName(for code: String) -> String {
        DenonAPI.availableInputs.first { $0.code == code }?.name ?? code
    }
}

// MARK: - Save Scene View

struct SaveSceneView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let receiverID: UUID
    let api: DenonAPI
    let receiver: DenonReceiver

    @State private var sceneName = ""
    @State private var includeZone2 = false
    @State private var includeZone3 = false

    private var isFormValid: Bool { !sceneName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Scene Name", text: $sceneName)
                        .textContentType(.name)
                } header: {
                    Text("Name")
                }

                Section {
                    LabeledContent("Input", value: inputName(for: api.state.currentInput))
                    LabeledContent("Volume", value: "\(api.state.volume)")
                    LabeledContent("Surround", value: surroundName(for: api.state.surroundMode))
                    LabeledContent("Muted", value: api.state.isMuted ? "Yes" : "No")
                } header: {
                    Text("Main Zone Snapshot")
                }

                Section {
                    Toggle("Include Zone 2", isOn: $includeZone2)
                    if includeZone2 {
                        LabeledContent("Input", value: inputName(for: api.state.zone2.currentInput))
                        LabeledContent("Volume", value: "\(api.state.zone2.volume)")
                        LabeledContent("Muted", value: api.state.zone2.isMuted ? "Yes" : "No")
                    }

                    Toggle("Include Zone 3", isOn: $includeZone3)
                    if includeZone3 {
                        LabeledContent("Input", value: inputName(for: api.state.zone3.currentInput))
                        LabeledContent("Volume", value: "\(api.state.zone3.volume)")
                        LabeledContent("Muted", value: api.state.zone3.isMuted ? "Yes" : "No")
                    }
                } header: {
                    Text("Zones")
                } footer: {
                    Text("Enable zones to include their current settings in this scene.")
                }

                Section {
                    quickPresetButtons
                } header: {
                    Text("Quick Presets")
                } footer: {
                    Text("Tap a preset to prefill the name.")
                }
            }
            .navigationTitle("Save Scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveScene() }
                        .disabled(!isFormValid)
                }
            }
        }
    }

    private var quickPresetButtons: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
            presetButton("Movie Night", icon: "film.fill")
            presetButton("Music", icon: "music.note")
            presetButton("Party", icon: "party.popper.fill")
            presetButton("Gaming", icon: "gamecontroller.fill")
            presetButton("Late Night", icon: "moon.fill")
            presetButton("Morning", icon: "sunrise.fill")
        }
    }

    private func presetButton(_ name: String, icon: String) -> some View {
        Button {
            sceneName = name
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(name)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(sceneName == name ? .blue : .secondary)
    }

    private func saveScene() {
        guard isFormValid else { return }

        let scene = ReceiverScene(
            name: sceneName.trimmingCharacters(in: .whitespaces),
            receiverID: receiverID,
            inputCode: api.state.currentInput,
            volume: api.state.volume,
            surroundMode: api.state.surroundMode,
            isMuted: api.state.isMuted,
            zone2InputCode: includeZone2 ? api.state.zone2.currentInput : nil,
            zone2Volume: includeZone2 ? api.state.zone2.volume : nil,
            zone2IsMuted: includeZone2 ? api.state.zone2.isMuted : nil,
            zone3InputCode: includeZone3 ? api.state.zone3.currentInput : nil,
            zone3Volume: includeZone3 ? api.state.zone3.volume : nil,
            zone3IsMuted: includeZone3 ? api.state.zone3.isMuted : nil
        )
        modelContext.insert(scene)
        dismiss()
    }

    private func inputName(for code: String) -> String {
        DenonAPI.availableInputs.first { $0.code == code }?.name ?? code
    }

    private func surroundName(for code: String) -> String {
        DenonAPI.availableSurroundModes.first { $0.code == code }?.name ?? code
    }
}
