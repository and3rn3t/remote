//
//  ConnectionLogger.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import Foundation
import Observation

/// A single entry in the connection log.
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let category: Category
    let message: String

    enum Category: String {
        case connection = "Connection"
        case command = "Command"
        case response = "Response"
        case error = "Error"
        case info = "Info"
    }
}

/// Centralized, in-memory log store visible to the entire app.
@Observable
final class ConnectionLogger {
    static let shared = ConnectionLogger()

    private(set) var entries: [LogEntry] = []
    private let maxEntries = DenonConstants.maxLogEntries

    private init() {}

    func log(_ message: String, category: LogEntry.Category) {
        let entry = LogEntry(timestamp: Date(), category: category, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }

    /// Formats all entries into a plain-text string for export.
    func exportText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return entries.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.category.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
}
