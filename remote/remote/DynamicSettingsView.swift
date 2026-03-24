//
//  DynamicSettingsView.swift
//  remote
//

import SwiftUI

/// Extracted Dynamic Audio settings section from ReceiverControlView.
struct DynamicSettingsView: View {
    let api: DenonAPI
    let onError: (String) -> Void

    var body: some View {
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
                                    in: .rect(cornerRadius: 12)
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

    private func apiAction(_ action: @escaping () async throws -> Void) {
        Task {
            do { try await action() } catch { onError(error.localizedDescription) }
        }
    }
}
