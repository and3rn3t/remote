//
//  ZoneControlView.swift
//  remote
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Reusable control view for Zone 2 or Zone 3.
struct ZoneControlView: View {
    let zone: Int  // 2 or 3
    let receiver: DenonReceiver
    let api: DenonAPI
    @Binding var showingError: Bool

    @State private var volumeDebounceTask: Task<Void, Never>?

    private var zoneState: ZoneState {
        zone == 2 ? api.state.zone2 : api.state.zone3
    }

    var body: some View {
        VStack(spacing: 24) {
            powerControl
            volumeControl
            inputSelection
            refreshButton
        }
    }

    // MARK: - Power

    private var powerControl: some View {
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
                            apiAction { try await self.setPower(newValue) }
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

    // MARK: - Volume

    private var volumeControl: some View {
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
                                    try? await Task.sleep(for: .milliseconds(DenonConstants.volumeDebounceMilliseconds))
                                    guard !Task.isCancelled else { return }
                                    do {
                                        try await self.setVolume(target)
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
                            apiAction { try await self.volumeDown() }
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
                            apiAction { try await self.setMute(!self.zoneState.isMuted) }
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
                            apiAction { try await self.volumeUp() }
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

    // MARK: - Input Selection

    private var inputSelection: some View {
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
                    ForEach(DenonInputs.all, id: \.code) { input in
                        Button {
                            playHaptic(.light)
                            apiAction { try await self.setInput(input.code) }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: DenonInputs.icon(for: input.code))
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

    // MARK: - Refresh

    private var refreshButton: some View {
        GlassEffectContainer(spacing: 12.0) {
            Button {
                playHaptic(.light)
                apiAction { try await self.refreshState() }
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

    // MARK: - Zone-Specific Methods

    private func setPower(_ on: Bool) async throws {
        if zone == 2 { try await api.setZone2Power(on) }
        else { try await api.setZone3Power(on) }
    }

    private func setVolume(_ volume: Int) async throws {
        if zone == 2 { try await api.setZone2Volume(volume) }
        else { try await api.setZone3Volume(volume) }
    }

    private func volumeUp() async throws {
        if zone == 2 { try await api.zone2VolumeUp() }
        else { try await api.zone3VolumeUp() }
    }

    private func volumeDown() async throws {
        if zone == 2 { try await api.zone2VolumeDown() }
        else { try await api.zone3VolumeDown() }
    }

    private func setMute(_ muted: Bool) async throws {
        if zone == 2 { try await api.setZone2Mute(muted) }
        else { try await api.setZone3Mute(muted) }
    }

    private func setInput(_ input: String) async throws {
        if zone == 2 { try await api.setZone2Input(input) }
        else { try await api.setZone3Input(input) }
    }

    private func refreshState() async throws {
        if zone == 2 { try await api.refreshZone2State() }
        else { try await api.refreshZone3State() }
    }

    // MARK: - Helpers

    private func apiAction(_ action: @escaping () async throws -> Void) {
        Task {
            do { try await action() } catch {
                api.errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    #if canImport(UIKit)
    private func playHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    #else
    private func playHaptic(_ style: Any? = nil) {}
    #endif
}
