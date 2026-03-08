//
//  DenonReceiver.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import Foundation
import SwiftData

@Model
final class DenonReceiver {
    var id: UUID
    var name: String
    var ipAddress: String
    var port: Int
    var isFavorite: Bool
    var lastConnected: Date?
    var volumeLimit: Int

    init(name: String, ipAddress: String, port: Int = 23, isFavorite: Bool = false, volumeLimit: Int = 80) {
        self.id = UUID()
        self.name = name
        self.ipAddress = ipAddress
        self.port = port
        self.isFavorite = isFavorite
        self.lastConnected = nil
        self.volumeLimit = volumeLimit
    }
}
