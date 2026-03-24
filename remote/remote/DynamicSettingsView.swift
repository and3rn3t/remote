//
//  DynamicSettingsView.swift
//  remote
//

import SwiftUI

/// Audio processing settings: Dynamic EQ/Volume, Dialogue Enhancer, Night Mode,
/// Audyssey MultEQ, Cinema EQ, Tone Defeat, Subwoofer & LFE levels.
struct DynamicSettingsView: View {
    let api: DenonAPI
    let onError: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacingLG) {
            HStack {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.green)

                Text("Audio Processing")
                    .font(.headline)
            }
            .padding(.horizontal, Design.spacingXS)

            GlassEffectContainer(spacing: Design.spacingMD) {
                VStack(spacing: Design.spacingLG) {
                    // Dynamic EQ toggle
                    toggleRow(
                        icon: "ear.fill",
                        title: "Dynamic EQ",
                        isOn: api.state.dynamicEQ,
                        action: { try await api.setDynamicEQ($0) }
                    )

                    Divider()

                    // Dynamic Volume
                    optionRow(
                        icon: "speaker.wave.2.fill",
                        title: "Dynamic Volume",
                        current: api.state.dynamicVolume,
                        options: DenonDynamicVolume.options,
                        tint: .green,
                        action: { try await api.setDynamicVolume($0) }
                    )

                    Divider()

                    // Dialogue Enhancer
                    optionRow(
                        icon: "person.wave.2.fill",
                        title: "Dialogue Enhancer",
                        current: api.state.dialogueEnhancer,
                        options: DenonDialogueEnhancer.options,
                        tint: .cyan,
                        action: { try await api.setDialogueEnhancer($0) }
                    )

                    Divider()

                    // Night Mode
                    optionRow(
                        icon: "moon.fill",
                        title: "Night Mode",
                        current: api.state.nightMode,
                        options: DenonNightMode.options,
                        tint: .indigo,
                        action: { try await api.setNightMode($0) }
                    )

                    Divider()

                    // Audyssey MultEQ
                    optionRow(
                        icon: "waveform.path.ecg",
                        title: "MultEQ",
                        current: api.state.multEQ,
                        options: DenonMultEQ.options,
                        tint: .orange,
                        action: { try await api.setMultEQ($0) }
                    )

                    Divider()

                    // Cinema EQ toggle
                    toggleRow(
                        icon: "film.fill",
                        title: "Cinema EQ",
                        isOn: api.state.cinemaEQ,
                        action: { try await api.setCinemaEQ($0) }
                    )

                    Divider()

                    // Tone Defeat toggle
                    toggleRow(
                        icon: "waveform.slash",
                        title: "Tone Defeat",
                        isOn: api.state.toneDefeat,
                        action: { try await api.setToneDefeat($0) }
                    )

                    Divider()

                    // Subwoofer Level slider
                    sliderRow(
                        icon: "speaker.zzz.fill",
                        title: "Subwoofer",
                        value: api.state.subwooferLevel,
                        range: 38...62,
                        center: 50,
                        label: { DenonConstants.subwooferLabel($0) },
                        action: { try await api.setSubwooferLevel($0) }
                    )

                    Divider()

                    // LFE Level slider
                    sliderRow(
                        icon: "beats.headphones",
                        title: "LFE Level",
                        value: api.state.lfeLevel,
                        range: 0...10,
                        center: nil,
                        label: { $0 == 0 ? "0 dB" : "-\($0) dB" },
                        action: { try await api.setLFELevel($0) }
                    )
                }
                .padding(Design.cardPadding)
                .glassEffect(.regular, in: .rect(cornerRadius: Design.cornerRadiusLarge))
            }
        }
    }

    // MARK: - Reusable Row Components

    private func toggleRow(icon: String, title: String, isOn: Bool, action: @escaping (Bool) async throws -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.green)
            Text(title)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    playHaptic(.light)
                    apiAction { try await action(newValue) }
                }
            ))
            .labelsHidden()
            .accessibilityLabel(title)
            .accessibilityValue(isOn ? "On" : "Off")
        }
    }

    private func optionRow(
        icon: String,
        title: String,
        current: String,
        options: [(name: String, code: String)],
        tint: Color,
        action: @escaping (String) async throws -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Design.spacingMD) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(options.first { $0.code == current }?.name ?? current)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Design.spacingSM) {
                ForEach(options, id: \.code) { option in
                    Button {
                        playHaptic(.light)
                        apiAction { try await action(option.code) }
                    } label: {
                        Text(option.name)
                            .font(.caption)
                            .foregroundStyle(current == option.code ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Design.spacingMD)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        current == option.code ?
                            .regular.tint(tint).interactive() :
                            .regular.interactive(),
                        in: .rect(cornerRadius: Design.cornerRadius)
                    )
                    .accessibilityLabel("\(title) \(option.name)")
                    .accessibilityValue(current == option.code ? "Selected" : "")
                    .accessibilityAddTraits(current == option.code ? .isSelected : [])
                }
            }
        }
    }

    private func sliderRow(
        icon: String,
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        center: Int?,
        label: (Int) -> String,
        action: @escaping (Int) async throws -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Design.spacingSM) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.green)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(label(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { newValue in
                        let target = Int(newValue)
                        playHaptic(.light)
                        apiAction { try await action(target) }
                    }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .accessibilityLabel(title)
            .accessibilityValue(label(value))
        }
    }

    private func apiAction(_ action: @escaping () async throws -> Void) {
        Task {
            do { try await action() } catch { onError(error.localizedDescription) }
        }
    }
}
