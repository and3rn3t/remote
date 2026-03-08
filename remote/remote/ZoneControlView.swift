//
//  ZoneControlView.swift
//  remote
//

import SwiftUI

/// Reusable control view for Zone 2 or Zone 3.
struct ZoneControlView: View {
    let zone: DenonAPI.Zone
    let receiver: DenonReceiver
    let api: DenonAPI
    @Binding var showingError: Bool

    @State private var volumeDebounceTask: Task<Void, Never>?

    private var zoneState: ZoneState {
        api.state[keyPath: zone.keyPath]
    }

    private var zoneNumber: Int {
        zone == .zone2 ? 2 : 3
    }

    var body: some View {
        VStack(spacing: 24) {
            powerControl
            volumeControl
            inputSelection
            refreshButton
        }
        .onDisappear {
            volumeDebounceTask?.cancel()
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
                            apiAction { try await api.setZonePower(newValue, zone: zone) }
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
                                        try await api.setZoneVolume(target, zone: zone)
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
                    .accessibilityLabel("Zone \(zoneNumber) Volume")
                    .accessibilityValue("\(zoneState.volume) decibels")
                    .accessibilityHint("Adjusts volume from 0 to \(receiver.volumeLimit)")

                    HStack(spacing: 16) {
                        Button {
                            playHaptic(.light)
                            apiAction { try await api.zoneVolumeDown(zone) }
                        } label: {
                            Label("Volume Down", systemImage: "minus.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title)
                        }
                        .buttonStyle(.glass)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Zone \(zoneNumber) Volume Down")

                        Button {
                            playHaptic(.light)
                            apiAction { try await api.setZoneMute(!zoneState.isMuted, zone: zone) }
                        } label: {
                            Label("Mute", systemImage: zoneState.isMuted ? "speaker.slash.fill" : "speaker.fill")
                                .labelStyle(.iconOnly)
                                .font(.title3)
                        }
                        .buttonStyle(.glassProminent)
                        .glassEffect(.regular.tint(zoneState.isMuted ? .red : .blue).interactive(), in: .rect(cornerRadius: 12))
                        .accessibilityLabel(zoneState.isMuted ? "Zone \(zoneNumber) Unmute" : "Zone \(zoneNumber) Mute")

                        Button {
                            playHaptic(.light)
                            apiAction { try await api.zoneVolumeUp(zone) }
                        } label: {
                            Label("Volume Up", systemImage: "plus.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title)
                        }
                        .buttonStyle(.glass)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Zone \(zoneNumber) Volume Up")
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

                Text("Zone \(zoneNumber) Input")
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            InputSelectionGrid(currentInput: zoneState.currentInput) { code in
                apiAction { try await api.setZoneInput(code, zone: zone) }
            }
        }
    }

    // MARK: - Refresh

    private var refreshButton: some View {
        GlassEffectContainer(spacing: 12.0) {
            Button {
                playHaptic(.light)
                apiAction { try await api.refreshZoneState(zone) }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                    Text("Refresh Zone \(zoneNumber)")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.glass)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
            .accessibilityLabel("Refresh Zone \(zoneNumber) state")
        }
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
}
