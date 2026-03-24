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
        VStack(spacing: Design.spacingXL) {
            powerVolumeControl
            inputSelection
        }
        .onDisappear {
            volumeDebounceTask?.cancel()
        }
    }

    // MARK: - Power + Volume

    private var powerVolumeControl: some View {
        GlassEffectContainer(spacing: 0) {
            VStack(spacing: Design.spacingLG) {
                HStack(spacing: Design.spacingMD) {
                    Image(systemName: "power")
                        .font(.title3)
                        .foregroundStyle(zoneState.isPowerOn ? .green : .secondary)

                    Text(zoneState.isPowerOn ? "On" : "Standby")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

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

                Divider()

                VStack(spacing: Design.spacingMD) {
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

                    Slider(
                        value: Binding(
                            get: { Double(zoneState.volume) },
                            set: { newValue in
                                let target = Int(newValue)
                                api.state[keyPath: zone.keyPath].volume = target
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

                    HStack(spacing: Design.spacingLG) {
                        Button {
                            playHaptic(.light)
                            apiAction { try await api.zoneVolumeDown(zone) }
                        } label: {
                            Label("Volume Down", systemImage: "minus.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .frame(width: Design.circleButtonSize, height: Design.circleButtonSize)
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
                        .glassEffect(.regular.tint(zoneState.isMuted ? .red : .blue).interactive(), in: .rect(cornerRadius: Design.cornerRadius))
                        .accessibilityLabel(zoneState.isMuted ? "Zone \(zoneNumber) Unmute" : "Zone \(zoneNumber) Mute")

                        Button {
                            playHaptic(.light)
                            apiAction { try await api.zoneVolumeUp(zone) }
                        } label: {
                            Label("Volume Up", systemImage: "plus.circle.fill")
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .frame(width: Design.circleButtonSize, height: Design.circleButtonSize)
                        }
                        .buttonStyle(.glass)
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Zone \(zoneNumber) Volume Up")
                    }
                }
            }
            .padding(Design.cardPadding)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Design.cornerRadiusLarge))
        }
    }

    // MARK: - Input Selection

    private var inputSelection: some View {
        VStack(alignment: .leading, spacing: Design.spacingLG) {
            HStack {
                Image(systemName: "tv.and.hifispeaker.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)

                Text("Zone \(zoneNumber) Input")
                    .font(.headline)
            }
            .padding(.horizontal, Design.spacingXS)

            InputSelectionGrid(currentInput: zoneState.currentInput, aliases: api.state.inputAliases) { code in
                apiAction { try await api.setZoneInput(code, zone: zone) }
            }
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
