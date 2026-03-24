//
//  SystemSettingsView.swift
//  remote
//

import SwiftUI

/// System-level receiver settings: Display, Power Management, HDMI/Video, and Zone Stereo.
struct SystemSettingsView: View {
    let api: DenonAPI
    let onError: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacingLG) {
            HStack {
                Image(systemName: "gearshape.2.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("System")
                    .font(.headline)
            }
            .padding(.horizontal, Design.spacingXS)

            GlassEffectContainer(spacing: Design.spacingMD) {
                VStack(spacing: Design.spacingLG) {
                    // Signal Info (read-only)
                    if !api.state.signalInfo.isEmpty {
                        signalInfoRow
                        Divider()
                    }

                    // Dimmer
                    optionRow(
                        icon: "sun.min.fill",
                        title: "Display",
                        current: api.state.dimmer,
                        options: DenonDimmer.options,
                        tint: .yellow,
                        action: { try await api.setDimmer($0) }
                    )

                    Divider()

                    // ECO Mode
                    optionRow(
                        icon: "leaf.fill",
                        title: "ECO Mode",
                        current: api.state.ecoMode,
                        options: DenonEcoMode.options,
                        tint: .green,
                        action: { try await api.setEcoMode($0) }
                    )

                    Divider()

                    // Auto Standby
                    optionRow(
                        icon: "timer",
                        title: "Auto Standby",
                        current: api.state.autoStandby,
                        options: DenonAutoStandby.options,
                        tint: .orange,
                        action: { try await api.setAutoStandby($0) }
                    )

                    Divider()

                    // HDMI Monitor Output
                    optionRow(
                        icon: "tv.fill",
                        title: "HDMI Output",
                        current: api.state.hdmiMonitor,
                        options: DenonHDMIMonitor.options,
                        tint: .blue,
                        action: { try await api.setHDMIMonitor($0) }
                    )

                    Divider()

                    // HDMI Resolution
                    optionRow(
                        icon: "rectangle.on.rectangle",
                        title: "Resolution",
                        current: api.state.hdmiResolution,
                        options: DenonHDMIResolution.options,
                        tint: .purple,
                        action: { try await api.setHDMIResolution($0) }
                    )

                    Divider()

                    // Video Aspect
                    optionRow(
                        icon: "aspectratio.fill",
                        title: "Aspect Ratio",
                        current: api.state.videoAspect,
                        options: DenonVideoAspect.options,
                        tint: .teal,
                        action: { try await api.setVideoAspect($0) }
                    )

                    Divider()

                    // All-Zone Stereo
                    toggleRow(
                        icon: "music.note.house.fill",
                        title: "All-Zone Stereo",
                        isOn: api.state.allZoneStereo,
                        action: { try await api.setAllZoneStereo($0) }
                    )
                }
                .padding(Design.cardPadding)
                .glassEffect(.regular, in: .rect(cornerRadius: Design.cornerRadiusLarge))
            }
        }
    }

    // MARK: - Row Components

    private var signalInfoRow: some View {
        HStack {
            Image(systemName: "dot.radiowaves.right")
                .foregroundStyle(.blue)
            Text("Signal")
                .font(.subheadline)
            Spacer()
            Text(api.state.signalInfo)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Audio signal: \(api.state.signalInfo)")
    }

    private func toggleRow(icon: String, title: String, isOn: Bool, action: @escaping (Bool) async throws -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
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

    private func apiAction(_ action: @escaping () async throws -> Void) {
        Task {
            do { try await action() } catch { onError(error.localizedDescription) }
        }
    }
}
