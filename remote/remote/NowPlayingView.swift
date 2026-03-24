//
//  NowPlayingView.swift
//  remote
//

import SwiftUI

/// Extracted Now Playing section from ReceiverControlView.
struct NowPlayingView: View {
    let api: DenonAPI
    let onError: (String) -> Void

    var body: some View {
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
                        .font(.body)
                }
                .buttonStyle(.plain)
                .contentShape(.rect)
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

    private func apiAction(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                onError(error.localizedDescription)
            }
        }
    }
}
