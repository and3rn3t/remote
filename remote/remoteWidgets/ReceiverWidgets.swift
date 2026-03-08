//
//  ReceiverWidgets.swift
//  remoteWidgets
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline Provider

struct ReceiverStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReceiverStatusEntry {
        ReceiverStatusEntry(date: .now, status: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReceiverStatusEntry) -> Void) {
        let status = ReceiverStatus.load() ?? .placeholder
        completion(ReceiverStatusEntry(date: .now, status: status))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReceiverStatusEntry>) -> Void) {
        let status = ReceiverStatus.load() ?? .placeholder
        let entry = ReceiverStatusEntry(date: .now, status: status)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct ReceiverStatusEntry: TimelineEntry {
    let date: Date
    let status: ReceiverStatus
}

// MARK: - Small Widget View

struct SmallReceiverWidgetView: View {
    let entry: ReceiverStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hifispeaker.fill")
                    .font(.title2)
                    .foregroundStyle(entry.status.isPowerOn ? .green : .secondary)
                Spacer()
                Circle()
                    .fill(entry.status.isPowerOn ? .green : .red)
                    .frame(width: 10, height: 10)
            }

            Spacer()

            Text(entry.status.receiverName)
                .font(.headline)
                .lineLimit(1)

            Text(entry.status.isPowerOn ? "On" : "Standby")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium Widget View

struct MediumReceiverWidgetView: View {
    let entry: ReceiverStatusEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "hifispeaker.fill")
                        .foregroundStyle(entry.status.isPowerOn ? .green : .secondary)
                    Text(entry.status.receiverName)
                        .font(.headline)
                        .lineLimit(1)
                }

                if entry.status.isPowerOn {
                    Label("Vol: \(entry.status.volume)", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)

                    Label(inputDisplayName(entry.status.currentInput), systemImage: "arrow.right.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.purple)
                } else {
                    Text("Standby")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(entry.status.lastUpdated, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack {
                Spacer()
                Button(intent: TogglePowerIntent()) {
                    Image(systemName: "power")
                        .font(.title)
                        .foregroundStyle(entry.status.isPowerOn ? .green : .secondary)
                        .frame(width: 56, height: 56)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func inputDisplayName(_ code: String) -> String {
        ReceiverStatus.inputDisplayName(code)
    }
}

// MARK: - Widget Entry View

struct ReceiverWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ReceiverStatusEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallReceiverWidgetView(entry: entry)
        case .systemMedium:
            MediumReceiverWidgetView(entry: entry)
        default:
            SmallReceiverWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct ReceiverStatusWidget: Widget {
    let kind = "ReceiverStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReceiverStatusProvider()) { entry in
            ReceiverWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Receiver Status")
        .description("Shows the current status of your Denon receiver.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    ReceiverStatusWidget()
} timeline: {
    ReceiverStatusEntry(date: .now, status: .placeholder)
    ReceiverStatusEntry(date: .now, status: ReceiverStatus(
        receiverName: "Living Room",
        ipAddress: "192.168.1.100",
        port: 23,
        isPowerOn: true,
        volume: 45,
        currentInput: "GAME",
        lastUpdated: .now
    ))
}

#Preview("Medium", as: .systemMedium) {
    ReceiverStatusWidget()
} timeline: {
    ReceiverStatusEntry(date: .now, status: .placeholder)
}
