//
//  ReceiverStatus.swift
//  SharedModels
//

import Foundation

public struct ReceiverStatus: Codable, Sendable {
    public var receiverName: String
    public var ipAddress: String
    public var port: Int
    public var isPowerOn: Bool
    public var volume: Int
    public var currentInput: String
    public var lastUpdated: Date

    public static let appGroupID = "group.dev.andernet.remote"
    public static let statusKey = "lastReceiverStatus"

    public init(
        receiverName: String,
        ipAddress: String,
        port: Int,
        isPowerOn: Bool,
        volume: Int,
        currentInput: String,
        lastUpdated: Date
    ) {
        self.receiverName = receiverName
        self.ipAddress = ipAddress
        self.port = port
        self.isPowerOn = isPowerOn
        self.volume = volume
        self.currentInput = currentInput
        self.lastUpdated = lastUpdated
    }

    public static func load() -> Self? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = defaults.data(forKey: Self.statusKey) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    public func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.statusKey)
    }

    public static let placeholder = Self(
        receiverName: "Receiver",
        ipAddress: "0.0.0.0",
        port: 23,
        isPowerOn: false,
        volume: 0,
        currentInput: "—",
        lastUpdated: .now
    )

    /// Human-readable display name for a Denon input code.
    public static func inputDisplayName(_ code: String) -> String {
        let mapping: [String: String] = [
            "BD": "Blu-ray", "GAME": "Game", "MPLAY": "Media Player",
            "TV": "TV Audio", "SAT/CBL": "Cable/Sat", "DVD": "DVD",
            "AUX1": "AUX1", "AUX2": "AUX2", "TUNER": "Tuner",
            "BT": "Bluetooth", "USB/IPOD": "USB/iPod", "NET": "Network",
            "SPOTIFY": "Spotify",
        ]
        return mapping[code] ?? code
    }
}
