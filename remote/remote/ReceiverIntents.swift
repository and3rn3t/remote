//
//  ReceiverIntents.swift
//  remote
//
//  Created by Matt on 3/8/26.
//

import AppIntents
import Network
import Foundation

// MARK: - Power Intent

struct PowerOnIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn On Receiver"
    static var description = IntentDescription("Turns a Denon receiver on or off.")

    @Parameter(title: "Receiver")
    var receiver: ReceiverEntity

    @Parameter(title: "Power On", default: true)
    var powerOn: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Turn \(\.$receiver) \(\.$powerOn)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let command = powerOn ? "PWON" : "PWSTANDBY"
        let success = await IntentCommandSender.send(command, to: receiver.ipAddress, port: receiver.port)

        if success {
            return .result(dialog: "\(receiver.name) powered \(powerOn ? "on" : "off").")
        } else {
            throw IntentCommandError.connectionFailed
        }
    }
}

// MARK: - Set Volume Intent

struct SetVolumeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Receiver Volume"
    static var description = IntentDescription("Sets the volume on a Denon receiver.")

    @Parameter(title: "Receiver")
    var receiver: ReceiverEntity

    @Parameter(title: "Volume", inclusiveRange: (0, 80))
    var volume: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$receiver) volume to \(\.$volume)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Denon protocol: MV followed by two-digit volume (e.g. MV45)
        let command = String(format: "MV%02d", volume)
        let success = await IntentCommandSender.send(command, to: receiver.ipAddress, port: receiver.port)

        if success {
            return .result(dialog: "\(receiver.name) volume set to \(volume).")
        } else {
            throw IntentCommandError.connectionFailed
        }
    }
}

// MARK: - Set Input Intent

struct SetInputIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Receiver Input"
    static var description = IntentDescription("Changes the input source on a Denon receiver.")

    @Parameter(title: "Receiver")
    var receiver: ReceiverEntity

    @Parameter(title: "Input Source")
    var inputSource: InputSourceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$receiver) input to \(\.$inputSource)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let command = "SI\(inputSource.code)"
        let success = await IntentCommandSender.send(command, to: receiver.ipAddress, port: receiver.port)

        if success {
            return .result(dialog: "\(receiver.name) input set to \(inputSource.name).")
        } else {
            throw IntentCommandError.connectionFailed
        }
    }
}

// MARK: - Input Source Entity

struct InputSourceEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Input Source")

    static var defaultQuery = InputSourceEntityQuery()

    var id: String   // the Denon code
    var code: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct InputSourceEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [InputSourceEntity] {
        allSources().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [InputSourceEntity] {
        allSources()
    }

    private func allSources() -> [InputSourceEntity] {
        DenonInputs.all.map {
            InputSourceEntity(id: $0.code, code: $0.code, name: $0.name)
        }
    }
}

// MARK: - Mute Intent

struct ToggleMuteIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Receiver Mute"
    static var description = IntentDescription("Mutes or unmutes a Denon receiver.")

    @Parameter(title: "Receiver")
    var receiver: ReceiverEntity

    @Parameter(title: "Mute", default: true)
    var mute: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$receiver) mute \(\.$mute)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let command = mute ? "MUON" : "MUOFF"
        let success = await IntentCommandSender.send(command, to: receiver.ipAddress, port: receiver.port)

        if success {
            return .result(dialog: "\(receiver.name) \(mute ? "muted" : "unmuted").")
        } else {
            throw IntentCommandError.connectionFailed
        }
    }
}

// MARK: - Error

enum IntentCommandError: Error, CustomLocalizedStringResourceConvertible {
    case connectionFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .connectionFailed:
            return "Could not connect to the receiver. Make sure it is powered on and reachable."
        }
    }
}

// MARK: - Lightweight TCP Sender (shared with main app intents)

enum IntentCommandSender {
    static func send(_ command: String, to host: String, port: Int) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let queue = DispatchQueue(label: "dev.andernet.remote.intent.tcp")
            let continuationGuard = IntentContinuationGuard()

            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let data = Data("\(command)\r".utf8)
                    connection.send(content: data, completion: .contentProcessed { _ in
                        connection.cancel()
                        continuationGuard.resumeOnce { continuation.resume(returning: true) }
                    })
                case .failed:
                    connection.cancel()
                    continuationGuard.resumeOnce { continuation.resume(returning: false) }
                case .cancelled:
                    continuationGuard.resumeOnce { continuation.resume(returning: false) }
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + 3) {
                connection.cancel()
                continuationGuard.resumeOnce { continuation.resume(returning: false) }
            }
        }
    }
}

private final class IntentContinuationGuard: Sendable {
    nonisolated(unsafe) private let lock = NSLock()
    nonisolated(unsafe) private var resumed = false
    nonisolated func resumeOnce(_ action: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        action()
    }
}
