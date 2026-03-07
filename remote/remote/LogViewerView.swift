//
//  LogViewerView.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import SwiftUI

struct LogViewerView: View {
    @Environment(\.dismiss) private var dismiss
    private var logger = ConnectionLogger.shared
    @State private var showingShareSheet = false
    @State private var filterCategory: LogEntry.Category?

    private var filteredEntries: [LogEntry] {
        if let category = filterCategory {
            return logger.entries.filter { $0.category == category }
        }
        return logger.entries
    }

    var body: some View {
        NavigationStack {
            Group {
                if logger.entries.isEmpty {
                    ContentUnavailableView {
                        Label("No Logs", systemImage: "doc.text")
                    } description: {
                        Text("Connection logs will appear here when you connect to a receiver.")
                    }
                } else {
                    logList
                }
            }
            .navigationTitle("Connection Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button("All Categories") { filterCategory = nil }
                        Divider()
                        ForEach([LogEntry.Category.connection, .command, .response, .error, .info], id: \.rawValue) { category in
                            Button {
                                filterCategory = category
                            } label: {
                                Label(category.rawValue, systemImage: iconForCategory(category))
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: filterCategory != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }

                    Menu {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Export Logs", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            logger.clear()
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                let text = logger.exportText()
                ShareLink(item: text) {
                    Text("Share Logs")
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var logList: some View {
        List(filteredEntries.reversed()) { entry in
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconForCategory(entry.category))
                    .foregroundStyle(colorForCategory(entry.category))
                    .font(.caption)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.message)
                        .font(.caption.monospaced())
                        .lineLimit(3)

                    Text(entry.timestamp, format: .dateTime.hour().minute().second())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .listStyle(.plain)
    }

    private func iconForCategory(_ category: LogEntry.Category) -> String {
        switch category {
        case .connection: return "link"
        case .command: return "arrow.up.circle"
        case .response: return "arrow.down.circle"
        case .error: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }

    private func colorForCategory(_ category: LogEntry.Category) -> Color {
        switch category {
        case .connection: return .blue
        case .command: return .green
        case .response: return .purple
        case .error: return .red
        case .info: return .secondary
        }
    }
}

#Preview {
    LogViewerView()
}
