//
//  ReceiverScene.swift
//  remote
//
//  Created by Matt on 3/8/26.
//

import Foundation
import SwiftData

/// A saved receiver configuration that can be recalled later.
@Model
final class ReceiverScene {
    var id: UUID
    var name: String
    var receiverID: UUID
    var createdAt: Date

    // Main Zone snapshot
    var inputCode: String
    var volume: Int
    var surroundMode: String
    var isMuted: Bool

    // Zone 2 snapshot (optional — nil means zone was not included)
    var zone2InputCode: String?
    var zone2Volume: Int?
    var zone2IsMuted: Bool?

    // Zone 3 snapshot (optional)
    var zone3InputCode: String?
    var zone3Volume: Int?
    var zone3IsMuted: Bool?

    init(
        name: String,
        receiverID: UUID,
        inputCode: String,
        volume: Int,
        surroundMode: String,
        isMuted: Bool,
        zone2InputCode: String? = nil,
        zone2Volume: Int? = nil,
        zone2IsMuted: Bool? = nil,
        zone3InputCode: String? = nil,
        zone3Volume: Int? = nil,
        zone3IsMuted: Bool? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.receiverID = receiverID
        self.createdAt = Date()
        self.inputCode = inputCode
        self.volume = volume
        self.surroundMode = surroundMode
        self.isMuted = isMuted
        self.zone2InputCode = zone2InputCode
        self.zone2Volume = zone2Volume
        self.zone2IsMuted = zone2IsMuted
        self.zone3InputCode = zone3InputCode
        self.zone3Volume = zone3Volume
        self.zone3IsMuted = zone3IsMuted
    }

    /// Whether this scene includes Zone 2 settings.
    var hasZone2: Bool { zone2InputCode != nil }

    /// Whether this scene includes Zone 3 settings.
    var hasZone3: Bool { zone3InputCode != nil }
}
