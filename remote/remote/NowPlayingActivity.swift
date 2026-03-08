//
//  NowPlayingActivity.swift
//  remote
//

import ActivityKit
import Foundation
import SharedModels

// MARK: - Live Activity Manager

@Observable
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<NowPlayingAttributes>?

    /// Start or update a Live Activity for now playing content.
    func update(
        receiverName: String,
        inputSource: String,
        trackName: String,
        artistName: String,
        albumName: String,
        isPlaying: Bool,
        volume: Int
    ) {
        let contentState = NowPlayingAttributes.ContentState(
            trackName: trackName,
            artistName: artistName,
            albumName: albumName,
            isPlaying: isPlaying,
            volume: volume
        )

        if let currentActivity {
            // Update existing activity
            Task {
                await currentActivity.update(ActivityContent(state: contentState, staleDate: nil))
            }
        } else {
            // Start new activity
            let attributes = NowPlayingAttributes(
                receiverName: receiverName,
                inputSource: inputSource
            )
            do {
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: contentState, staleDate: nil),
                    pushType: nil
                )
            } catch {
                // Live Activities may not be available
            }
        }
    }

    /// End the current Live Activity.
    func end() {
        guard let currentActivity else { return }
        let finalState = NowPlayingAttributes.ContentState(
            trackName: "",
            artistName: "",
            albumName: "",
            isPlaying: false,
            volume: 0
        )
        Task {
            await currentActivity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        self.currentActivity = nil
    }

    /// Whether a Live Activity is currently running.
    var isActive: Bool {
        currentActivity != nil
    }
}
