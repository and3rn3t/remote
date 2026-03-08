//
//  NowPlayingLiveActivity.swift
//  remoteWidgets
//

import ActivityKit
import SwiftUI
import WidgetKit

struct NowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            // Lock Screen / Banner presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: iconForInput(context.attributes.inputSource))
                        .font(.title2)
                        .foregroundStyle(.purple)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                        Text("Vol: \(context.state.volume)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.trackName.isEmpty ? "No Track" : context.state.trackName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.receiverName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(context.state.albumName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: iconForInput(context.attributes.inputSource))
                    .foregroundStyle(.purple)
            } compactTrailing: {
                Text(context.state.trackName.isEmpty ? "—" : context.state.trackName)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(maxWidth: 80)
            } minimal: {
                Image(systemName: context.state.isPlaying ? "music.note" : "pause.fill")
                    .foregroundStyle(.purple)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<NowPlayingAttributes>) -> some View {
        HStack(spacing: 16) {
            // Input icon
            Image(systemName: iconForInput(context.attributes.inputSource))
                .font(.largeTitle)
                .foregroundStyle(.purple)
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.trackName.isEmpty ? "No Track" : context.state.trackName)
                    .font(.headline)
                    .lineLimit(1)
                Text(context.state.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !context.state.albumName.isEmpty {
                    Text(context.state.albumName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: context.state.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(.purple)
                Text("Vol \(context.state.volume)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.7))
        .activitySystemActionForegroundColor(.white)
    }

    // MARK: - Helpers

    private func iconForInput(_ code: String) -> String {
        switch code {
        case "BT": return "bluetooth"
        case "SPOTIFY": return "music.note"
        case "NET": return "network"
        case "USB/IPOD": return "ipod"
        case "MPLAY": return "play.rectangle.fill"
        default: return "hifispeaker.fill"
        }
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content, using: NowPlayingAttributes(
    receiverName: "Living Room",
    inputSource: "SPOTIFY"
)) {
    NowPlayingLiveActivity()
} contentStates: {
    NowPlayingAttributes.ContentState(
        trackName: "Bohemian Rhapsody",
        artistName: "Queen",
        albumName: "A Night at the Opera",
        isPlaying: true,
        volume: 45
    )
    NowPlayingAttributes.ContentState(
        trackName: "",
        artistName: "",
        albumName: "",
        isPlaying: false,
        volume: 0
    )
}
