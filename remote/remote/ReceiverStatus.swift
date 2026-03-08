//
//  ReceiverStatus.swift
//  remote
//

import Foundation

struct ReceiverStatus: Codable {
    var receiverName: String
    var ipAddress: String
    var port: Int
    var isPowerOn: Bool
    var volume: Int
    var currentInput: String
    var lastUpdated: Date

    static let appGroupID = "group.dev.andernet.remote"
    static let statusKey = "lastReceiverStatus"

    static func load() -> Self? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = defaults.data(forKey: Self.statusKey) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.statusKey)
    }

    static let placeholder = Self(
        receiverName: "Receiver",
        ipAddress: "0.0.0.0",
        port: 23,
        isPowerOn: false,
        volume: 0,
        currentInput: "—",
        lastUpdated: .now
    )
}
