//
//  DenonCommandSender.swift
//  SharedModels
//

import Foundation
import Network
import os

/// Lightweight TCP command sender for Denon receivers, used by App Intents and widgets.
public enum DenonCommandSender {
    public static func send(_ command: String, to host: String, port: Int, timeout: TimeInterval = 5.0) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let queue = DispatchQueue(label: "dev.andernet.remote.tcp")
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

            queue.asyncAfter(deadline: .now() + timeout) {
                connection.cancel()
                continuationGuard.resumeOnce { continuation.resume(returning: false) }
            }
        }
    }
}

/// Ensures a continuation is only resumed once, even with multiple callbacks.
public final class ContinuationGuard: Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)
    public init() {}
    public func resumeOnce(_ action: () -> Void) {
        let shouldResume = lock.withLock { alreadyResumed -> Bool in
            guard !alreadyResumed else { return false }
            alreadyResumed = true
            return true
        }
        if shouldResume { action() }
    }
}
