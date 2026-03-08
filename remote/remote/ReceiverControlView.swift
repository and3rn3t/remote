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
    }
    
    // MARK: - Connected View
    
    private var connectedView: some View {
        VStack(spacing: 24) {
            // Zone Picker
            zonePicker
            
            if selectedZone == 0 {
                // Main Zone
                powerControl
                volumeControl
                inputSelection
                surroundModeSection
                
                // Now Playing (only for network sources)
                if api.isNetworkSource {
                    nowPlayingSection
                }
                
                // Tuner presets (only when tuner is active)
                if api.isTunerActive {
                    tunerPresetsSection
                }
                
                toneControlSection
                dynamicSettingsSection
                sleepTimerSection
                quickActions
            } else if selectedZone == 1 {
                zoneControlView(
                    zone: 2,
                    zoneState: api.state.zone2,
                    setPower: api.setZone2Power,
                    setVolume: api.setZone2Volume,
                    volumeUp: api.zone2VolumeUp,
                    volumeDown: api.zone2VolumeDown,
                    setMute: api.setZone2Mute,
                    setInput: api.setZone2Input,
                    refreshState: api.refreshZone2State
                )
            } else {
                zoneControlView(
                    zone: 3,
                    zoneState: api.state.zone3,
                    setPower: api.setZone3Power,
                    setVolume: api.setZone3Volume,
                    volumeUp: api.zone3VolumeUp,
                    volumeDown: api.zone3VolumeDown,
                    setMute: api.setZone3Mute,
                    setInput: api.setZone3Input,
                    refreshState: api.refreshZone3State
                )
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
                            Task {
                                do {
                                    try await api.setPower(newValue)
                                } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
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
                // Volume Level Display
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
                
                // Volume Slider
                VStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { Double(api.state.volume) },
                            set: { newValue in
                                let target = Int(newValue)
                                api.state.volume = target
                                volumeDebounceTask?.cancel()
                                volumeDebounceTask = Task {
                                    try? await Task.sleep(for: .milliseconds(150))
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
                    
                    // Volume buttons
                    HStack(spacing: 16) {
                        Button {
                            playHaptic(.light)
                            Task {
                                do {
                                    try await api.volumeDown()
                                } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            Label("Volume Down", systemImage: "minus.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title)
                        }
                        .buttonStyle(.glass)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Volume Down")
                        
                        Button {
                            playHaptic(.light)
                            Task {
                                do {
                                    try await api.setMute(!api.state.isMuted)
                                } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
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
                            Task {
                                do {
                                    try await api.volumeUp()
                                } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            Label("Volume Up", systemImage: "plus.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title)
                        }
                        .buttonStyle(.glass)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Volume Up")
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
                    ForEach(DenonAPI.availableInputs, id: \.code) { input in
                        Button {
                            playHaptic(.light)
                            Task {
                                do {
                                    try await api.setInput(input.code)
                                } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: iconForInput(input.code))
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
                    ForEach(DenonAPI.sleepTimerOptions, id: \.value) { option in
                        let isActive = (option.value == "OFF" && api.state.sleepTimer == nil) ||
                            (Int(option.value) == api.state.sleepTimer)
                        Button {
                            playHaptic(.light)
                            Task {
                                do {
                                    try await api.setSleepTimer(option.value)
                                } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
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
                    // Bass
                    VStack(spacing: 8) {
                        HStack {
                            Text("Bass")
                                .font(.subheadline)
                            Spacer()
                            Text(toneLabel(api.state.bass))
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(api.state.bass) },
                                set: { newValue in
                                    let target = Int(newValue)
                                    api.state.bass = target
                                    toneDebounceTask?.cancel()
                                    toneDebounceTask = Task {
                                        try? await Task.sleep(for: .milliseconds(150))
                                        guard !Task.isCancelled else { return }
                                        do {
                                            try await api.setBass(target)
                                        } catch {
                                            api.errorMessage = error.localizedDescription
                                            showingError = true
                                        }
                                    }
                                }
                            ),
                            in: 44...56,
                            step: 1
                        )
                        .tint(.cyan)
                        .accessibilityLabel("Bass")
                        .accessibilityValue(toneLabel(api.state.bass))
                        .accessibilityHint("Adjusts bass from minus 6 to plus 6 decibels")
                    }
                    
                    // Treble
                    VStack(spacing: 8) {
                        HStack {
                            Text("Treble")
                                .font(.subheadline)
                            Spacer()
                            Text(toneLabel(api.state.treble))
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(api.state.treble) },
                                set: { newValue in
                                    let target = Int(newValue)
                                    api.state.treble = target
                                    toneDebounceTask?.cancel()
                                    toneDebounceTask = Task {
                                        try? await Task.sleep(for: .milliseconds(150))
                                        guard !Task.isCancelled else { return }
                                        do {
                                            try await api.setTreble(target)
                                        } catch {
                                            api.errorMessage = error.localizedDescription
                                            showingError = true
                                        }
                                    }
                                }
                            ),
                            in: 44...56,
                            step: 1
                        )
                        .tint(.cyan)
                        .accessibilityLabel("Treble")
                        .accessibilityValue(toneLabel(api.state.treble))
                        .accessibilityHint("Adjusts treble from minus 6 to plus 6 decibels")
                    }
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
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
                    // Dynamic EQ Toggle
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
                                Task {
                                    do {
                                        try await api.setDynamicEQ(newValue)
                                    } catch {
                                        api.errorMessage = error.localizedDescription
                                        showingError = true
                                    }
                                }
                            }
                        ))
                        .labelsHidden()
                        .accessibilityLabel("Dynamic EQ")
                        .accessibilityValue(api.state.dynamicEQ ? "On" : "Off")
                    }
                    
                    Divider()
                    
                    // Dynamic Volume
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
                            ForEach(DenonAPI.dynamicVolumeOptions, id: \.code) { option in
                                Button {
                                    playHaptic(.light)
                                    Task {
                                        do {
                                            try await api.setDynamicVolume(option.code)
                                        } catch {
                                            api.errorMessage = error.localizedDescription
                                            showingError = true
                                        }
                                    }
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
                        Task {
                            do {
                                try await api.tunerPresetDown()
                            } catch {
                                api.errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
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
                        Task {
                            do {
                                try await api.tunerPresetUp()
                            } catch {
                                api.errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
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
                        Task {
                            do {
                                try await api.refreshState()
                            } catch {
                                api.errorMessage = error.localizedDescription
                                showingError = true
                            }
                        }
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
    
    // MARK: - Zone Control View (Zone 2/3)
    
    private func zoneControlView(
        zone: Int,
        zoneState: ZoneState,
        setPower: @escaping (Bool) async throws -> Void,
        setVolume: @escaping (Int) async throws -> Void,
        volumeUp: @escaping () async throws -> Void,
        volumeDown: @escaping () async throws -> Void,
        setMute: @escaping (Bool) async throws -> Void,
        setInput: @escaping (String) async throws -> Void,
        refreshState: @escaping () async throws -> Void
    ) -> some View {
        VStack(spacing: 24) {
            // Zone Power
            zonePowerControl(zoneState: zoneState, setPower: setPower)
            
            // Zone Volume
            zoneVolumeControl(
                zone: zone,
                zoneState: zoneState,
                setVolume: setVolume,
                volumeUp: volumeUp,
                volumeDown: volumeDown,
                setMute: setMute
            )
            
            // Zone Input
            zoneInputSelection(zone: zone, zoneState: zoneState, setInput: setInput)
            
            // Zone Refresh
            GlassEffectContainer(spacing: 12.0) {
                Button {
                    playHaptic(.light)
                    Task {
                        do {
                            try await refreshState()
                        } catch {
                            api.errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                        Text("Refresh Zone \(zone)")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.glass)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                .accessibilityLabel("Refresh Zone \(zone) state")
            }
        }
    }
    
    private func zonePowerControl(zoneState: ZoneState, setPower: @escaping (Bool) async throws -> Void) -> some View {
        GlassEffectContainer(spacing: 20.0) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "power")
                        .font(.title2)
                        .foregroundStyle(zoneState.isPowerOn ? .green : .secondary)
                    
                    Text(zoneState.isPowerOn ? "Powered On" : "Standby")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { zoneState.isPowerOn },
                        set: { newValue in
                            playHaptic()
                            Task {
                                do {
                                    try await setPower(newValue)
                                } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        }
                    ))
                    .labelsHidden()
                    .accessibilityLabel("Zone Power")
                    .accessibilityValue(zoneState.isPowerOn ? "On" : "Standby")
                }
            }
            .padding(20)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
    }
    
    private func zoneVolumeControl(
        zone: Int,
        zoneState: ZoneState,
        setVolume: @escaping (Int) async throws -> Void,
        volumeUp: @escaping () async throws -> Void,
        volumeDown: @escaping () async throws -> Void,
        setMute: @escaping (Bool) async throws -> Void
    ) -> some View {
        GlassEffectContainer(spacing: 20.0) {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: zoneState.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                        .font(.title2)
                        .foregroundStyle(zoneState.isMuted ? .red : .blue)
                    
                    Text("Volume")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(zoneState.volume)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                }
                
                VStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { Double(zoneState.volume) },
                            set: { newValue in
                                let target = Int(newValue)
                                volumeDebounceTask?.cancel()
                                volumeDebounceTask = Task {
                                    try? await Task.sleep(for: .milliseconds(150))
                                    guard !Task.isCancelled else { return }
                                    do {
                                        try await setVolume(target)
                                    } catch {
                                        api.errorMessage = error.localizedDescription
                                        showingError = true
                                    }
                                }
                            }
                        ),
                        in: 0...Double(receiver.volumeLimit)
                    )
                    .tint(Double(zoneState.volume) > Double(receiver.volumeLimit) * 0.9 ? .red : .blue)
                    .accessibilityLabel("Zone \(zone) Volume")
                    .accessibilityValue("\(zoneState.volume) decibels")
                    .accessibilityHint("Adjusts volume from 0 to \(receiver.volumeLimit)")
                    
                    HStack(spacing: 16) {
                        Button {
                            playHaptic(.light)
                            Task {
                                do { try await volumeDown() } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            Label("Volume Down", systemImage: "minus.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title)
                        }
                        .buttonStyle(.glass)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Zone \(zone) Volume Down")
                        
                        Button {
                            playHaptic(.light)
                            Task {
                                do { try await setMute(!zoneState.isMuted) } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            Label("Mute", systemImage: zoneState.isMuted ? "speaker.slash.fill" : "speaker.fill")
                                .labelStyle(.iconOnly)
                                .font(.title3)
                        }
                        .buttonStyle(.glassProminent)
                        .glassEffect(.regular.tint(zoneState.isMuted ? .red : .blue).interactive(), in: .rect(cornerRadius: 12))
                        .accessibilityLabel(zoneState.isMuted ? "Zone \(zone) Unmute" : "Zone \(zone) Mute")
                        
                        Button {
                            playHaptic(.light)
                            Task {
                                do { try await volumeUp() } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            Label("Volume Up", systemImage: "plus.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title)
                        }
                        .buttonStyle(.glass)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Zone \(zone) Volume Up")
                    }
                }
            }
            .padding(20)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }
    
    private func zoneInputSelection(zone: Int, zoneState: ZoneState, setInput: @escaping (String) async throws -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tv.and.hifispeaker.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)
                
                Text("Zone \(zone) Input")
                    .font(.headline)
            }
            .padding(.horizontal, 4)
            
            GlassEffectContainer(spacing: 12.0) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(DenonAPI.availableInputs, id: \.code) { input in
                        Button {
                            playHaptic(.light)
                            Task {
                                do { try await setInput(input.code) } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: iconForInput(input.code))
                                    .font(.title2)
                                    .foregroundStyle(zoneState.currentInput == input.code ? .white : .primary)
                                
                                Text(input.name)
                                    .font(.caption)
                                    .foregroundStyle(zoneState.currentInput == input.code ? .white : .primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            zoneState.currentInput == input.code ?
                                .regular.tint(.purple).interactive() :
                                .regular.interactive(),
                            in: .rect(cornerRadius: 12)
                        )
                        .accessibilityLabel(input.name)
                        .accessibilityValue(zoneState.currentInput == input.code ? "Selected" : "")
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
                    ForEach(DenonAPI.availableSurroundModes, id: \.code) { mode in
                        Button {
                            playHaptic(.light)
                            Task {
                                do {
                                    try await api.setSurroundMode(mode.code)
                                } catch {
                                    api.errorMessage = error.localizedDescription
                                    showingError = true
                                }
                            }
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
                    Task {
                        do { try await api.refreshNowPlaying() } catch {
                            api.errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
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
                    
                    // Transport Controls
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
            Task {
                do { try await action() } catch {
                    api.errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        } label: {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.glass)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
    }
    
    // MARK: - Disconnected View
    
    private var disconnectedView: some View {
        ContentUnavailableView {
            VStack(spacing: 8) {
                Image(systemName: api.isReconnecting ? "arrow.triangle.2.circlepath" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 36))
                    .symbolEffect(.pulse, isActive: api.isReconnecting)
                Text(api.isReconnecting ? "Reconnecting…" : "Not Connected")
                    .font(.headline)
            }
        } description: {
            VStack(spacing: 16) {
                Text("Connect to **\(receiver.name)** at \(receiver.ipAddress)")
                
                if api.isReconnecting {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Attempt \(api.currentReconnectAttempt) of 5")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Retrying in ~\(Int(pow(2.0, Double(api.currentReconnectAttempt - 1))))s…")
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
    
    private func iconForInput(_ code: String) -> String {
        switch code {
        case "BD": return "opticaldiscdrive.fill"
        case "GAME": return "gamecontroller.fill"
        case "MPLAY": return "play.rectangle.fill"
        case "TV": return "tv.fill"
        case "SAT/CBL": return "square.stack.3d.up.fill"
        case "DVD": return "opticaldiscdrive"
        case "AUX1", "AUX2": return "cable.connector"
        case "TUNER": return "radio.fill"
        case "BT": return "bluetooth"
        case "USB/IPOD": return "ipod"
        case "NET": return "network"
        case "SPOTIFY": return "music.note"
        default: return "rectangle.fill"
        }
    }
    
    private func playHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    
    /// Converts raw tone value (44–56) to a dB label relative to center (50 = 0 dB).
    private func toneLabel(_ value: Int) -> String {
        let db = value - 50
        if db > 0 { return "+\(db) dB" }
        if db < 0 { return "\(db) dB" }
        return "0 dB"
    }
}

#Preview {
    NavigationStack {
        ReceiverControlView(receiver: DenonReceiver(name: "Living Room", ipAddress: "192.168.1.100"))
    }
    .modelContainer(for: DenonReceiver.self, inMemory: true)
}
