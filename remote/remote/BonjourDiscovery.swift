//
//  BonjourDiscovery.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import Foundation
import Network
import Observation

/// A discovered receiver on the local network.
struct DiscoveredReceiver: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let host: String
    let port: Int
}

/// Scans the local network for Denon AVR receivers using Bonjour/mDNS.
///
/// Denon receivers advertise HTTP services that can be discovered via `_http._tcp`.
/// Some models also advertise a Denon-specific `_denon._tcp` service.
/// We browse both to maximize discovery coverage.
@Observable
final class BonjourDiscovery {
    var discoveredReceivers: [DiscoveredReceiver] = []
    var isScanning = false
    var errorMessage: String?

    private var httpBrowser: NWBrowser?
    private var denonBrowser: NWBrowser?
    private var resolvedHosts: Set<String> = []
    private var scanTimeoutTask: Task<Void, Never>?

    /// Start scanning for Denon receivers on the local network.
    /// Automatically stops after `timeout` seconds.
    func startScan(timeout: TimeInterval = 10) {
        stopScan()

        discoveredReceivers = []
        resolvedHosts = []
        errorMessage = nil
        isScanning = true

        // Browse for HTTP services (most Denon receivers advertise this)
        let httpParams = NWParameters()
        httpParams.includePeerToPeer = true
        httpBrowser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: "local."), using: httpParams)
        configureBrowser(httpBrowser)

        // Browse for Denon-specific services
        let denonParams = NWParameters()
        denonParams.includePeerToPeer = true
        denonBrowser = NWBrowser(for: .bonjour(type: "_denon._tcp", domain: "local."), using: denonParams)
        configureBrowser(denonBrowser)

        httpBrowser?.start(queue: .main)
        denonBrowser?.start(queue: .main)

        // Auto-stop after timeout
        scanTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(timeout))
            if !Task.isCancelled {
                stopScan()
            }
        }
    }

    /// Stop the current scan.
    func stopScan() {
        scanTimeoutTask?.cancel()
        scanTimeoutTask = nil
        httpBrowser?.cancel()
        denonBrowser?.cancel()
        httpBrowser = nil
        denonBrowser = nil
        isScanning = false
    }

    // MARK: - Private

    private func configureBrowser(_ browser: NWBrowser?) {
        guard let browser else { return }

        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                self?.errorMessage = "Network scan failed: \(error.localizedDescription)"
                self?.isScanning = false
            case .cancelled:
                break
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            for result in results {
                self.resolveResult(result)
            }
        }
    }

    private func resolveResult(_ result: NWBrowser.Result) {
        // Filter for likely Denon devices by name
        guard case .service(let name, let type, _, _) = result.endpoint else { return }

        let lowerName = name.lowercased()
        let denonKeywords = ["denon", "avr", "avc", "heos"]
        let isLikelyDenon = denonKeywords.contains { lowerName.contains($0) }

        // For _http._tcp results, only include if name matches Denon keywords
        // For _denon._tcp results, always include them
        if type == "_http._tcp." && !isLikelyDenon {
            return
        }

        // Resolve the endpoint to get host and port
        let connection = NWConnection(to: result.endpoint, using: .tcp)
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else {
                connection.cancel()
                return
            }
            switch state {
            case .ready:
                if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = innerEndpoint {
                    let hostStr = "\(host)"
                    let portInt = Int(port.rawValue)

                    // Deduplicate by host
                    if !self.resolvedHosts.contains(hostStr) {
                        self.resolvedHosts.insert(hostStr)
                        let receiver = DiscoveredReceiver(
                            name: name,
                            host: hostStr,
                            port: portInt
                        )
                        self.discoveredReceivers.append(receiver)
                    }
                }
                connection.cancel()
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
}
