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

    static func load() -> ReceiverStatus? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: statusKey) else { return nil }
        return try? JSONDecoder().decode(ReceiverStatus.self, from: data)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.statusKey)
    }
}
