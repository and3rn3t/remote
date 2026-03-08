//
//  ReceiverControlView.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import SwiftUI
import SwiftData
import UIKit

struct ReceiverControlView: View {
    @Environment(\.modelContext) private var modelContext
    let receiver: DenonReceiver

    @State private var api = DenonAPI()
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var showingSettings = false
    @State private var selectedZone = 0  // 0 = Main, 1 = Zone 2, 2 = Zone 3
    @State private var volumeDebounceTask: Task<Void, Never>?
    @State private var toneDebounceTask: Task<Void, Never>?
    @State private var showingScenes = false
    @State private var showingSaveScene = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if api.isConnected {
                    connectedView
                } else {
                    disconnectedView
                }
            }
            .padding()
        }
        .navigationTitle(receiver.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(id: "receiver-toolbar") {
            ToolbarItem(id: "connection") {
                connectionButton
            }
        }
        .onDisappear {
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
        VStack(spacing: 24) {
            zonePicker

            if selectedZone == 0 {
                powerControl
                volumeControl
                inputSelection
                surroundModeSection

                if api.isNetworkSource {
                    nowPlayingSection
                }

                if api.isTunerActive {
                    tunerPresetsSection
                }

                toneControlSection
                dynamicSettingsSection
                sleepTimerSection
                scenesSection
                quickActions
            } else if selectedZone == 1 {
                ZoneControlView(zone: 2, receiver: receiver, api: api, showingError: $showingError)
            } else {
                ZoneControlView(zone: 3, receiver: receiver, api: api, showingError: $showingError)
            }
        }
        .animation(.smooth, value: selectedZone)
    }

    private var powerControl: some View {
        GlassEffectContainer(spacing: 20.0) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "power")
                        .font(.title2)
                        .foregroundStyle(api.state.isPowerOn ? .green : .secondary)

                    Text(api.state.isPowerOn ? "Powered On" : "Standby")
                        .font(.headline)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { api.state.isPowerOn },
                        set: { newValue in
                            playHaptic()
                            apiAction { try await api.setPower(newValue) }
                        }
                    ))
                    .labelsHidden()
                    .accessibilityLabel("Power")
                    .accessibilityValue(api.state.isPowerOn ? "On" : "Standby")
                }
            }
            .padding(20)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
    }

    private var volumeControl: some View {
        GlassEffectContainer(spacing: 20.0) {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: api.state.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                        .font(.title2)
                        .foregroundStyle(api.state.isMuted ? .red : .blue)

                    Text("Volume")
                        .font(.headline)

                    Spacer()

                    Text("\(api.state.volume)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }

                VStack(spacing: 12) {
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

                    HStack(spacing: 16) {
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
                            apiAction { try await api.setMute(!api.state.isMuted) }
                        } label: {
                            Label("Mute", systemImage: api.state.isMuted ? "speaker.slash.fill" : "speaker.fill")
                                .labelStyle(.iconOnly)
                                .font(.title3)
                        }
                        .buttonStyle(.glassProminent)
                        .glassEffect(.regular.tint(api.state.isMuted ? .red : .blue).interactive(), in: .rect(cornerRadius: 12))
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
            }
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }

    private var inputSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tv.and.hifispeaker.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)

                Text("Input Source")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(DenonInputs.all, id: \.code) { input in
                        Button {
                            playHaptic(.light)
                            apiAction { try await api.setInput(input.code) }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: DenonInputs.icon(for: input.code))
                                    .font(.title2)
                                    .foregroundStyle(api.state.currentInput == input.code ? .white : .primary)

                                Text(input.name)
                                    .font(.caption)
                                    .foregroundStyle(api.state.currentInput == input.code ? .white : .primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            api.state.currentInput == input.code ?
                                .regular.tint(.purple).interactive() :
                                .regular.interactive(),
                            in: .rect(cornerRadius: 12)
                        )
                        .accessibilityLabel(input.name)
                        .accessibilityValue(api.state.currentInput == input.code ? "Selected" : "")
                        .accessibilityAddTraits(api.state.currentInput == input.code ? .isSelected : [])
                    }
                }
            }
        }
    }

    // MARK: - Surround Mode

    private var surroundModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
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
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            api.state.surroundMode == mode.code ?
                                .regular.tint(.teal).interactive() :
                                .regular.interactive(),
                            in: .rect(cornerRadius: 12)
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
        VStack(alignment: .leading, spacing: 16) {
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
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
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
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            isActive ?
                                .regular.tint(.indigo).interactive() :
                                .regular.interactive(),
                            in: .rect(cornerRadius: 12)
                        )
                        .accessibilityLabel(option.name)
                        .accessibilityValue(isActive ? "Selected" : "")
                        .accessibilityAddTraits(isActive ? .isSelected : [])
                    }
                }
            }
        }
    }

    // MARK: - Tone Controls

    private var toneControlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(.cyan)

                Text("Tone Controls")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                VStack(spacing: 20) {
                    toneSlider(label: "Bass",
                               value: api.state.bass,
                               onSet: { api.state.bass = $0 },
                               apiCall: api.setBass)

                    toneSlider(label: "Treble",
                               value: api.state.treble,
                               onSet: { api.state.treble = $0 },
                               apiCall: api.setTreble)
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }
    }

    private func toneSlider(
        label: String,
        value: Int,
        onSet: @escaping (Int) -> Void,
        apiCall: @escaping (Int) async throws -> Void
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(DenonConstants.toneLabel(value))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { newValue in
                        let target = Int(newValue)
                        onSet(target)
                        toneDebounceTask?.cancel()
                        toneDebounceTask = Task {
                            try? await Task.sleep(for: .milliseconds(DenonConstants.volumeDebounceMilliseconds))
                            guard !Task.isCancelled else { return }
                            do {
                                try await apiCall(target)
                            } catch {
                                api.errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
                    }
                ),
                in: Double(DenonConstants.toneMin)...Double(DenonConstants.toneMax),
                step: 1
            )
            .tint(.cyan)
            .accessibilityLabel(label)
            .accessibilityValue(DenonConstants.toneLabel(value))
            .accessibilityHint("Adjusts \(label.lowercased()) from minus 6 to plus 6 decibels")
        }
    }

    // MARK: - Dynamic Settings

    private var dynamicSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.green)

                Text("Dynamic Audio")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "ear.fill")
                            .foregroundStyle(.green)
                        Text("Dynamic EQ")
                            .font(.subheadline)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { api.state.dynamicEQ },
                            set: { newValue in
                                playHaptic(.light)
                                apiAction { try await api.setDynamicEQ(newValue) }
                            }
                        ))
                        .labelsHidden()
                        .accessibilityLabel("Dynamic EQ")
                        .accessibilityValue(api.state.dynamicEQ ? "On" : "Off")
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.green)
                            Text("Dynamic Volume")
                                .font(.subheadline)
                            Spacer()
                            Text(api.state.dynamicVolume)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 8) {
                            ForEach(DenonDynamicVolume.options, id: \.code) { option in
                                Button {
                                    playHaptic(.light)
                                    apiAction { try await api.setDynamicVolume(option.code) }
                                } label: {
                                    Text(option.name)
                                        .font(.caption)
                                        .foregroundStyle(api.state.dynamicVolume == option.code ? .white : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .glassEffect(
                                    api.state.dynamicVolume == option.code ?
                                        .regular.tint(.green).interactive() :
                                        .regular.interactive(),
                                    in: .rect(cornerRadius: 10)
                                )
                                .accessibilityLabel("Dynamic Volume \(option.name)")
                                .accessibilityValue(api.state.dynamicVolume == option.code ? "Selected" : "")
                                .accessibilityAddTraits(api.state.dynamicVolume == option.code ? .isSelected : [])
                            }
                        }
                    }
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }
    }

    // MARK: - Tuner Presets

    private var tunerPresetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "radio.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)

                Text("Tuner Presets")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                HStack(spacing: 12) {
                    Button {
                        playHaptic(.light)
                        apiAction { try await api.tunerPresetDown() }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                            Text("Previous")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    .accessibilityLabel("Previous tuner preset")

                    Button {
                        playHaptic(.light)
                        apiAction { try await api.tunerPresetUp() }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                            Text("Next")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    .accessibilityLabel("Next tuner preset")
                }
            }
        }
    }

    // MARK: - Scenes

    private var scenesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "theatermasks.fill")
                    .font(.title3)
                    .foregroundStyle(.mint)

                Text("Scenes")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                HStack(spacing: 12) {
                    Button {
                        playHaptic(.light)
                        showingSaveScene = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.title2)
                            Text("Save Scene")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    .accessibilityLabel("Save current configuration as a scene")

                    Button {
                        playHaptic(.light)
                        showingScenes = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "theatermasks.fill")
                                .font(.title2)
                            Text("All Scenes")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    .accessibilityLabel("View and recall saved scenes")
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                Text("Quick Actions")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                HStack(spacing: 12) {
                    Button {
                        playHaptic(.light)
                        apiAction { try await api.refreshState() }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                            Text("Refresh")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    .accessibilityLabel("Refresh receiver state")
                    .keyboardShortcut("r", modifiers: .command)

                    Button {
                        playHaptic(.light)
                        showingSettings = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                            Text("Settings")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glass)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    .accessibilityLabel("Settings")
                }
            }
        }
    }

    // MARK: - Now Playing

    private var nowPlayingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.pink)

                Text("Now Playing")
                    .font(.headline)

                Spacer()

                Button {
                    apiAction { try await api.refreshNowPlaying() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh Now Playing")
            }
            .padding(.horizontal, 4)

            GlassEffectContainer(spacing: 12.0) {
                VStack(spacing: 16) {
                    if api.state.nowPlaying.isEmpty {
                        Text("No media information available")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if !api.state.nowPlaying.line3.isEmpty {
                                Text(api.state.nowPlaying.line3)
                                    .font(.headline)
                                    .lineLimit(2)
                            }
                            if !api.state.nowPlaying.line1.isEmpty {
                                Text(api.state.nowPlaying.line1)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if !api.state.nowPlaying.line2.isEmpty {
                                Text(api.state.nowPlaying.line2)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 20) {
                        transportButton(systemImage: "backward.fill", label: "Previous") {
                            try await api.transportSkipPrevious()
                        }
                        transportButton(systemImage: "play.fill", label: "Play") {
                            try await api.transportPlay()
                        }
                        transportButton(systemImage: "pause.fill", label: "Pause") {
                            try await api.transportPause()
                        }
                        transportButton(systemImage: "stop.fill", label: "Stop") {
                            try await api.transportStop()
                        }
                        transportButton(systemImage: "forward.fill", label: "Next") {
                            try await api.transportSkipNext()
                        }
                    }
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }
    }

    private func transportButton(systemImage: String, label: String, action: @escaping () async throws -> Void) -> some View {
        Button {
            playHaptic(.light)
            apiAction(action)
        } label: {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.glass)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
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
            VStack(spacing: 8) {
                Image(systemName: api.isReconnecting ? "arrow.triangle.2.circlepath" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 36))
                    .symbolEffect(.pulse, isActive: api.isReconnecting)
                Text(api.isReconnecting ? "Reconnecting\u{2026}" : "Not Connected")
                    .font(.headline)
            }
        } description: {
            VStack(spacing: 16) {
                Text("Connect to **\(receiver.name)** at \(receiver.ipAddress)")

                if api.isReconnecting {
                    VStack(spacing: 8) {
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

    private func playHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

#Preview {
    NavigationStack {
        ReceiverControlView(receiver: DenonReceiver(name: "Living Room", ipAddress: "192.168.1.100"))
    }
    .modelContainer(for: DenonReceiver.self, inMemory: true)
}
