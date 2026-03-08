//
//  NowPlayingAttributes.swift
//  SharedModels
//

import ActivityKit
import Foundation

public struct NowPlayingAttributes: ActivityAttributes {
    /// Fixed context — receiver identity
    public var receiverName: String
    public var inputSource: String

    public init(receiverName: String, inputSource: String) {
        self.receiverName = receiverName
        self.inputSource = inputSource
    }

    /// Dynamic state — updates during activity lifecycle
    public struct ContentState: Codable, Hashable {
        public var trackName: String
        public var artistName: String
        public var albumName: String
        public var isPlaying: Bool
        public var volume: Int

        public init(
            trackName: String,
            artistName: String,
            albumName: String,
            isPlaying: Bool,
            volume: Int
        ) {
            self.trackName = trackName
            self.artistName = artistName
            self.albumName = albumName
            self.isPlaying = isPlaying
            self.volume = volume
        }
    }
}
