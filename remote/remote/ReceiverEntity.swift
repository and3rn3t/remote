//
//  ReceiverEntity.swift
//  remote
//
//  Created by Matt on 3/8/26.
//

import AppIntents
import SwiftData
import Foundation

/// An AppEntity that lets Siri and Shortcuts discover receivers stored in SwiftData.
struct ReceiverEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Receiver")

    static var defaultQuery = ReceiverEntityQuery()

    var id: UUID
    var name: String
    var ipAddress: String
    var port: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(ipAddress)")
    }
}

struct ReceiverEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ReceiverEntity] {
        try allReceivers().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ReceiverEntity] {
        try allReceivers()
    }

    private static let sharedContainer: ModelContainer? = {
        try? ModelContainer(for: DenonReceiver.self)
    }()

    private func allReceivers() throws -> [ReceiverEntity] {
        guard let container = Self.sharedContainer else { return [] }
        let context = ModelContext(container)
        let receivers = try context.fetch(FetchDescriptor<DenonReceiver>())
        return receivers.map {
            ReceiverEntity(id: $0.id, name: $0.name, ipAddress: $0.ipAddress, port: $0.port)
        }
    }
}
