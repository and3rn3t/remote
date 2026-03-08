//
//  NowPlayingAttributes.swift
//  remoteWidgets
//

import ActivityKit
import Foundation

struct NowPlayingAttributes: ActivityAttributes {
    /// Fixed context — receiver identity
    var receiverName: String
    var inputSource: String

    /// Dynamic state — updates during activity lifecycle
    struct ContentState: Codable, Hashable {
        var trackName: String
        var artistName: String
        var albumName: String
        var isPlaying: Bool
        var volume: Int
    }
}
