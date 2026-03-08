//
//  TogglePowerIntent.swift
//  remoteWidgets
//

import AppIntents
import Network
import WidgetKit

struct TogglePowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Receiver Power"
    static var description = IntentDescription("Toggles the power state of your Denon receiver.")

    func perform() async throws -> some IntentResult {
        guard var status = ReceiverStatus.load() else {
            return .result()
        }

        let command = status.isPowerOn ? "PWSTANDBY" : "PWON"
        let success = await DenonCommandSender.send(command, to: status.ipAddress, port: status.port)

        if success {
            status.isPowerOn.toggle()
            status.lastUpdated = .now
            status.save()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "ReceiverStatusWidget")
        return .result()
    }
}

// MARK: - Lightweight TCP Command Sender

enum DenonCommandSender {
    static func send(_ command: String, to host: String, port: Int) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let queue = DispatchQueue(label: "dev.andernet.remote.widget.tcp")
            let continuationGuard = ContinuationGuard()

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

            // Timeout after 3 seconds
            queue.asyncAfter(deadline: .now() + 3) {
                connection.cancel()
                continuationGuard.resumeOnce { continuation.resume(returning: false) }
            }
        }
    }
}

/// Ensures a continuation is only resumed once, even with multiple callbacks.
private final class ContinuationGuard: @unchecked Sendable {
    private var resumed = false
    func resumeOnce(_ action: () -> Void) {
        guard !resumed else { return }
        resumed = true
        action()
    }
}
