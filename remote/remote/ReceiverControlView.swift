//
//  ReceiverControlView.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import SwiftUI
import SwiftData

struct ReceiverControlView: View {
    @Environment(\.modelContext) private var modelContext
    let receiver: DenonReceiver

    @State private var api = DenonAPI()
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var showingSettings = false
    @State private var selectedZone = 0  // 0 = Main, 1 = Zone 2, 2 = Zone 3
    @State private var volumeDebounceTask: Task<Void, Never>?
    @State private var showingScenes = false
    @State private var showingSaveScene = false
    @State private var showSecondaryControls = false

    var body: some View {
        ScrollView {
            VStack(spacing: Design.spacingXL) {
                if api.isConnected {
                    connectedView
                } else {
                    disconnectedView
                }
            }
            .padding()
        }
        .refreshable {
            try? await api.refreshState()
        }
        .navigationTitle(receiver.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(id: "receiver-toolbar") {
            ToolbarItem(id: "settings", placement: .topBarTrailing) {
                Button {
                    playHaptic()
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(id: "connection", placement: .topBarTrailing) {
                connectionButton
            }
        }
        .onAppear {
            if !api.isConnected && !api.isReconnecting {
                connectToReceiver()
            }
        }
        .onDisappear {
            volumeDebounceTask?.cancel()
            api.disconnect()
        }
        .sheet(isPresented: $showingSettings) {
            ReceiverSettingsView(receiver: receiver, api: api)
        }
        .sheet(isPresented: $showingScenes) {
            SceneListView(receiverID: receiver.id, api: api, receiver: receiver)
        }
        .sheet(isPresented: $showingSaveScene) {
            SaveSceneView(receiverID: receiver.id, api: api, receiver: receiver)
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("Retry") {
                connectToReceiver()
            }
            Button("OK", role: .cancel) { }
        } message: {
            if let error = api.errorMessage {
                Text(error)
            }
        }
        .background {
            Button("") {
                Task {
                    try? await api.setPower(!api.state.isPowerOn)
                }
            }
            .keyboardShortcut("p", modifiers: .command)
            .hidden()
        }
    }

    // MARK: - Connected View

    private var connectedView: some View {
        VStack(spacing: Design.spacingXL) {
            zonePicker

            if selectedZone == 0 {
                powerVolumeControl
                inputSelection

                if api.isNetworkSource {
                    NowPlayingView(api: api) { errorMsg in
                        api.errorMessage = errorMsg
                        showingError = true
                    }
                }

                if showSecondaryControls {
                    VStack(spacing: Design.spacingXL) {
                        if api.isTunerActive {
                            tunerPresetsSection
                        }

                        surroundModeSection

                        ToneControlView(api: api) { errorMsg in
                            api.errorMessage = errorMsg
                            showingError = true
                        }
                        DynamicSettingsView(api: api) { errorMsg in
                            api.errorMessage = errorMsg
                            showingError = true
                        }
                        sleepTimerSection
                        scenesSection
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                moreControlsToggle
            } else if selectedZone == 1 {
                ZoneControlView(zone: .zone2, receiver: receiver, api: api, showingError: $showingError)
            } else {
                ZoneControlView(zone: .zone3, receiver: receiver, api: api, showingError: $showingError)
            }
        }
        .animation(.smooth, value: selectedZone)
        .animation(.smooth, value: showSecondaryControls)
    }

    private var powerVolumeControl: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: Design.spacingLG) {
                // Power row
                HStack(spacing: Design.spacingMD) {
                    Image(systemName: "power")
                        .font(.title3)
                        .foregroundStyle(api.state.isPowerOn ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))

                    Text(api.state.isPowerOn ? "On" : "Standby")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { api.state.isPowerOn },
                        set: { newValue in
                            playHaptic()
                            withAnimation(.smooth(duration: 0.3)) {
                                apiAction { try await api.setPower(newValue) }
                            }
                        }
                    ))
                    .labelsHidden()
                    .accessibilityLabel("Power")
                    .accessibilityValue(api.state.isPowerOn ? "On" : "Standby")
                }

                Divider()

                // Volume header
                HStack {
                    Image(systemName: api.state.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                        .font(.title2)
                        .foregroundStyle(api.state.isMuted ? .red : .blue)
                        .contentTransition(.symbolEffect(.replace))

                    Text("Volume")
                        .font(.headline)

                    Spacer()

                    Text("\(api.state.volume)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.2), value: api.state.volume)
                }

                // Volume slider
                Slider(
                    value: Binding(
                        get: { Double(api.state.volume) },
                        set: { newValue in
                            let target = Int(newValue)
                            api.state.volume = target
                            volumeDebounceTask?.cancel()
                            volumeDebounceTask = Task {
                                try? await Task.sleep(for: .milliseconds(DenonConstants.volumeDebounceMilliseconds))
                                guard !Task.isCancelled else { return }
                                do {
                                    try await api.setVolume(target)
                                } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        }
                    ),
                    in: 0...Double(receiver.volumeLimit)
                )
                .tint(Double(api.state.volume) > Double(receiver.volumeLimit) * 0.9 ? .red : .blue)
                .accessibilityLabel("Volume")
                .accessibilityValue("\(api.state.volume) decibels")
                .accessibilityHint("Adjusts volume from 0 to \(receiver.volumeLimit)")

                // Volume step buttons
                HStack(spacing: Design.spacingLG) {
                    Button {
                        playHaptic(.light)
                        apiAction { try await api.volumeDown() }
                    } label: {
                        Label("Volume Down", systemImage: "minus.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Volume Down")
                    .keyboardShortcut(.downArrow, modifiers: .command)

                    Button {
                        playHaptic(.light)
                        withAnimation(.smooth(duration: 0.25)) {
                            apiAction { try await api.setMute(!api.state.isMuted) }
                        }
                    } label: {
                        Label("Mute", systemImage: api.state.isMuted ? "speaker.slash.fill" : "speaker.fill")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffect(.regular.tint(api.state.isMuted ? .red : .blue).interactive(), in: .rect(cornerRadius: Design.cornerRadius))
                    .accessibilityLabel(api.state.isMuted ? "Unmute" : "Mute")
                    .accessibilityValue(api.state.isMuted ? "Muted" : "Unmuted")
                    .keyboardShortcut("m", modifiers: .command)

                    Button {
                        playHaptic(.light)
                        apiAction { try await api.volumeUp() }
                    } label: {
                        Label("Volume Up", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Volume Up")
                    .keyboardShortcut(.upArrow, modifiers: .command)
                }
            }
            .padding(Design.cardPadding)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Design.cornerRadiusLarge))
        }
    }

    private var inputSelection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLG) {
            HStack {
                Image(systemName: "tv.and.hifispeaker.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)

                Text("Input Source")
                    .font(.headline)
            }
            .padding(.horizontal, Design.spacingXS)

            InputSelectionGrid(currentInput: api.state.currentInput, aliases: api.state.inputAliases) { code in
                apiAction { try await api.setInput(code) }
            }
        }
    }

    // MARK: - Surround Mode

    private var surroundModeSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLG) {
            HStack {
                Image(systemName: "hifispeaker.and.appletv.fill")
                    .font(.title3)
                    .foregroundStyle(.teal)

                Text("Surround Mode")
                    .font(.headline)

                Spacer()

                Text(api.state.surroundMode)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Design.spacingXS)

            GlassEffectContainer(spacing: Design.spacingMD) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Design.gridMinLarge))], spacing: Design.spacingMD) {
                    ForEach(DenonSurroundModes.all, id: \.code) { mode in
                        Button {
                            playHaptic(.light)
                            apiAction { try await api.setSurroundMode(mode.code) }
                        } label: {
                            Text(mode.name)
                                .font(.caption)
                                .foregroundStyle(api.state.surroundMode == mode.code ? .white : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Design.spacingMD)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            api.state.surroundMode == mode.code ?
                                .regular.tint(.teal).interactive() :
                                .regular.interactive(),
                            in: .rect(cornerRadius: Design.cornerRadius)
                        )
                        .accessibilityLabel(mode.name)
                        .accessibilityValue(api.state.surroundMode == mode.code ? "Selected" : "")
                        .accessibilityAddTraits(api.state.surroundMode == mode.code ? .isSelected : [])
                    }
                }
            }
        }
    }

    // MARK: - Sleep Timer

    private var sleepTimerSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLG) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .font(.title3)
                    .foregroundStyle(.indigo)

                Text("Sleep Timer")
                    .font(.headline)

                Spacer()

                if let minutes = api.state.sleepTimer {
                    Text("\(minutes) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Design.spacingXS)

            GlassEffectContainer(spacing: Design.spacingMD) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Design.gridMinSmall))], spacing: Design.spacingMD) {
                    ForEach(DenonSleepTimer.options, id: \.value) { option in
                        let isActive = (option.value == "OFF" && api.state.sleepTimer == nil) ||
                            (Int(option.value) == api.state.sleepTimer)
                        Button {
                            playHaptic(.light)
                            apiAction { try await api.setSleepTimer(option.value) }
                        } label: {
                            Text(option.name)
                                .font(.caption)
                                .foregroundStyle(isActive ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Design.spacingMD)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            isActive ?
                                .regular.tint(.indigo).interactive() :
                                .regular.interactive(),
                            in: .rect(cornerRadius: Design.cornerRadius)
                        )
                        .accessibilityLabel(option.name)
                        .accessibilityValue(isActive ? "Selected" : "")
                        .accessibilityAddTraits(isActive ? .isSelected : [])
                    }
                }
            }
        }
    }

    // MARK: - Tuner Presets

    private var tunerPresetsSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLG) {
            HStack {
                Image(systemName: "radio.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)

                Text("Tuner Presets")
                    .font(.headline)
            }
            .padding(.horizontal, Design.spacingXS)

            GlassEffectContainer(spacing: Design.spacingMD) {
                HStack(spacing: Design.spacingMD) {
                    Button {
                        playHaptic(.light)
                        apiAction { try await api.tunerPresetDown() }
                    } label: {
                        VStack(spacing: Design.spacingSM) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                            Text("Previous")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.spacingLG)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Design.cornerRadius))
                    .accessibilityLabel("Previous tuner preset")

                    Button {
                        playHaptic(.light)
                        apiAction { try await api.tunerPresetUp() }
                    } label: {
                        VStack(spacing: Design.spacingSM) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                            Text("Next")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.spacingLG)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Design.cornerRadius))
                    .accessibilityLabel("Next tuner preset")
                }
            }
        }
    }

    // MARK: - Scenes

    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLG) {
            HStack {
                Image(systemName: "theatermasks.fill")
                    .font(.title3)
                    .foregroundStyle(.mint)

                Text("Scenes")
                    .font(.headline)
            }
            .padding(.horizontal, Design.spacingXS)

            GlassEffectContainer(spacing: Design.spacingMD) {
                HStack(spacing: Design.spacingMD) {
                    Button {
                        playHaptic(.light)
                        showingSaveScene = true
                    } label: {
                        VStack(spacing: Design.spacingSM) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.title2)
                            Text("Save Scene")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.spacingLG)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Design.cornerRadius))
                    .accessibilityLabel("Save current configuration as a scene")

                    Button {
                        playHaptic(.light)
                        showingScenes = true
                    } label: {
                        VStack(spacing: Design.spacingSM) {
                            Image(systemName: "theatermasks.fill")
                                .font(.title2)
                            Text("All Scenes")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.spacingLG)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Design.cornerRadius))
                    .accessibilityLabel("View and recall saved scenes")
                }
            }
        }
    }

    // MARK: - More Controls Toggle

    private var moreControlsToggle: some View {
        Button {
            playHaptic(.light)
            withAnimation(.smooth) {
                showSecondaryControls.toggle()
            }
        } label: {
            Label(
                showSecondaryControls ? "Fewer Controls" : "More Controls",
                systemImage: showSecondaryControls ? "chevron.up" : "chevron.down"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .contentTransition(.symbolEffect(.replace))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.spacingMD)
        }
        .buttonStyle(.glass)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Design.cornerRadius))
        .accessibilityLabel(showSecondaryControls ? "Collapse secondary controls" : "Expand secondary controls")
        .accessibilityHint(showSecondaryControls ? "Hides surround mode, tone, sleep and scene controls" : "Shows surround mode, tone, sleep and scene controls")
    }

    // MARK: - Zone Picker

    private var zonePicker: some View {
        Picker("Zone", selection: $selectedZone) {
            Text("Main").tag(0)
            Text("Zone 2").tag(1)
            Text("Zone 3").tag(2)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Zone selector")
    }

    // MARK: - Disconnected View

    private var disconnectedView: some View {
        ContentUnavailableView {
            VStack(spacing: Design.spacingSM) {
                Image(systemName: api.isReconnecting ? "arrow.triangle.2.circlepath" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 36))
                    .symbolEffect(.pulse, isActive: api.isReconnecting)
                Text(api.isReconnecting ? "Reconnecting\u{2026}" : "Not Connected")
                    .font(.headline)
            }
        } description: {
            VStack(spacing: Design.spacingLG) {
                Text("Connect to **\(receiver.name)** at \(receiver.ipAddress)")

                if api.isReconnecting {
                    VStack(spacing: Design.spacingSM) {
                        ProgressView()
                        Text("Attempt \(api.currentReconnectAttempt) of \(DenonConstants.maxReconnectAttempts)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Retrying in ~\(Int(pow(2.0, Double(api.currentReconnectAttempt - 1))))s\u{2026}")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let error = api.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } actions: {
            Button {
                playHaptic()
                connectToReceiver()
            } label: {
                if isConnecting {
                    ProgressView()
                } else {
                    Text("Connect")
                }
            }
            .buttonStyle(.glassProminent)
            .disabled(isConnecting || api.isReconnecting)
        }
    }

    // MARK: - Connection Button

    private var connectionButton: some View {
        Button {
            playHaptic()
            if api.isConnected {
                api.disconnect()
            } else {
                connectToReceiver()
            }
        } label: {
            Label(
                api.isConnected ? "Disconnect" : "Connect",
                systemImage: api.isConnected ? "wifi.circle.fill" : "wifi.slash"
            )
        }
        .disabled(isConnecting)
    }

    // MARK: - Helper Methods

    private func connectToReceiver() {
        isConnecting = true
        api.errorMessage = nil

        Task {
            do {
                try await api.connect(to: receiver)
                receiver.lastConnected = Date()
                AppSettings.lastConnectedReceiverID = receiver.id.uuidString
            } catch {
                api.errorMessage = error.localizedDescription
                showingError = true
            }
            isConnecting = false
        }
    }

    private func apiAction(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                api.errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReceiverControlView(receiver: DenonReceiver(name: "Living Room", ipAddress: "192.168.1.100"))
    }
    .modelContainer(for: DenonReceiver.self, inMemory: true)
}
