//
//  DenonAPI.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import Foundation
import Observation
import WidgetKit
import ActivityKit

/// State for a single zone (Main, Zone 2, or Zone 3)
struct ZoneState {
    var isPowerOn: Bool = false
    var volume: Int = 0  // Range: 0-98
    var isMuted: Bool = false
    var currentInput: String = "Unknown"
}

/// Now Playing information from network sources
struct NowPlayingInfo {
    var line1: String = ""  // NSE1 — e.g. artist
    var line2: String = ""  // NSE2 — e.g. album
    var line3: String = ""  // NSE3 — e.g. track name
    var line4: String = ""  // NSE4 — extra info

    var isEmpty: Bool {
        line1.isEmpty && line2.isEmpty && line3.isEmpty && line4.isEmpty
    }
}

/// Represents the current state of the Denon AVR
struct DenonState {
    var isPowerOn: Bool = false
    var volume: Int = 0  // Range: 0-98 (0.0 to 98.0 dB)
    var isMuted: Bool = false
    var currentInput: String = "Unknown"
    var surroundMode: String = "Unknown"

    // Zone 2/3
    var zone2 = ZoneState()
    var zone3 = ZoneState()

    // Now Playing
    var nowPlaying = NowPlayingInfo()

    // Sleep Timer (minutes remaining, nil = off)
    var sleepTimer: Int?

    // Tone/EQ (raw protocol values: 44–56, where 50 = 0 dB)
    var bass: Int = 50
    var treble: Int = 50

    // Dynamic Volume (OFF, LIT, MED, HEV)
    var dynamicVolume: String = "OFF"
    var dynamicEQ: Bool = false

    // Receiver Info
    var receiverModel: String = ""
    var firmwareVersion: String = ""
}

/// Manages communication with Denon AVR via the network API
@Observable
final class DenonAPI {
    var state = DenonState()
    var isConnected = false
    var errorMessage: String?
    var isReconnecting = false
    var currentReconnectAttempt = 0

    private var receiver: DenonReceiver?
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var readBuffer = [UInt8](repeating: 0, count: DenonConstants.readBufferSize)
    private var connectionMonitorTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let logger = ConnectionLogger.shared
    private let liveActivity = LiveActivityManager.shared

    /// Timeout for establishing a TCP connection, in seconds.
    var connectionTimeout: TimeInterval = DenonConstants.connectionTimeout

    // MARK: - Connection Management

    func connect(to receiver: DenonReceiver) async throws {
        self.receiver = receiver
        reconnectAttempts = 0
        logger.log("Connecting to \(receiver.name) at \(receiver.ipAddress):\(receiver.port)", category: .connection)
        try await establishConnection(to: receiver)
    }

    private func establishConnection(to receiver: DenonReceiver) async throws {
        // Open TCP connection to receiver
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        CFStreamCreatePairWithSocketToHost(
            kCFAllocatorDefault,
            receiver.ipAddress as CFString,
            UInt32(receiver.port),
            &readStream,
            &writeStream
        )

        guard let readStream = readStream?.takeRetainedValue(),
              let writeStream = writeStream?.takeRetainedValue() else {
            logger.log("Stream creation failed", category: .error)
            throw DenonError.connectionFailed
        }

        inputStream = readStream as InputStream
        outputStream = writeStream as OutputStream

        inputStream?.open()
        outputStream?.open()

        // Wait for streams to open with timeout
        let deadline = Date().addingTimeInterval(connectionTimeout)
        while Date() < deadline {
            if inputStream?.streamStatus == .open && outputStream?.streamStatus == .open {
                break
            }
            if inputStream?.streamStatus == .error || outputStream?.streamStatus == .error {
                cleanupStreams()
                logger.log("Connection refused — stream error", category: .error)
                throw DenonError.connectionRefused
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        // Check if connection succeeded
        guard inputStream?.streamStatus == .open && outputStream?.streamStatus == .open else {
            cleanupStreams()
            logger.log("Connection timed out after \(connectionTimeout)s", category: .error)
            throw DenonError.connectionTimeout
        }

        isConnected = true
        errorMessage = nil
        logger.log("Connected successfully", category: .connection)

        // Start monitoring connection health
        startConnectionMonitor()

        // Query initial state
        try await refreshState()
    }

    func disconnect() {
        logger.log("Disconnecting", category: .connection)
        connectionMonitorTask?.cancel()
        connectionMonitorTask = nil
        cleanupStreams()
        isConnected = false
        reconnectAttempts = 0
        liveActivity.end()
    }

    private func cleanupStreams() {
        inputStream?.close()
        outputStream?.close()
        inputStream = nil
        outputStream = nil
    }

    // MARK: - Connection Monitoring & Reconnection

    private func startConnectionMonitor() {
        connectionMonitorTask?.cancel()
        connectionMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }

                guard let self else { return }

                // Check if streams are still healthy
                let inputOk = self.inputStream?.streamStatus == .open
                let outputOk = self.outputStream?.streamStatus == .open

                if self.isConnected && (!inputOk || !outputOk) {
                    self.isConnected = false
                    self.errorMessage = DenonError.disconnected.localizedDescription
                    self.logger.log("Connection lost — streams unhealthy", category: .error)
                    await self.attemptReconnect()
                }
            }
        }
    }

    private func attemptReconnect() async {
        guard let receiver, reconnectAttempts < DenonConstants.maxReconnectAttempts else {
            logger.log("Reconnection failed after \(DenonConstants.maxReconnectAttempts) attempts", category: .error)
            errorMessage = "Reconnection failed after \(DenonConstants.maxReconnectAttempts) attempts. Please reconnect manually."
            isReconnecting = false
            return
        }

        reconnectAttempts += 1
        currentReconnectAttempt = reconnectAttempts
        isReconnecting = true
        logger.log("Reconnect attempt \(reconnectAttempts)/\(DenonConstants.maxReconnectAttempts)", category: .connection)

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay = pow(2.0, Double(reconnectAttempts - 1))
        try? await Task.sleep(for: .seconds(delay))

        guard !Task.isCancelled else {
            isReconnecting = false
            return
        }

        cleanupStreams()

        do {
            try await establishConnection(to: receiver)
            reconnectAttempts = 0
            isReconnecting = false
        } catch {
            if reconnectAttempts < DenonConstants.maxReconnectAttempts {
                await attemptReconnect()
            } else {
                isReconnecting = false
                errorMessage = "Reconnection failed after \(DenonConstants.maxReconnectAttempts) attempts. Please reconnect manually."
            }
        }
    }

    // MARK: - Command Sending

    private func sendCommand(_ command: String) async throws {
        guard isConnected, let outputStream = outputStream else {
            throw DenonError.notConnected
        }

        let commandString = "\(command)\r"
        let data = Array(commandString.utf8)

        logger.log("TX: \(command)", category: .command)
        let bytesWritten = outputStream.write(data, maxLength: data.count)

        if bytesWritten < 0 {
            throw DenonError.commandFailed
        }

        // Brief delay to allow receiver to process
        try await Task.sleep(for: .milliseconds(100))
    }

    // MARK: - State Queries

    func refreshState() async throws {
        try await sendCommand("PW?")
        try await sendCommand("MV?")
        try await sendCommand("MU?")
        try await sendCommand("SI?")
        try await sendCommand("MS?")
        try await sendCommand("SLP?")
        try await sendCommand("PSBAS ?")
        try await sendCommand("PSTRE ?")
        try await sendCommand("PSDYNVOL ?")
        try await sendCommand("PSDYNEQ ?")

        // Read responses
        try await Task.sleep(for: .milliseconds(500))
        readResponses()
    }

    private func readResponses() {
        guard let inputStream = inputStream else { return }

        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(&readBuffer, maxLength: readBuffer.count)
            if bytesRead > 0 {
                if let response = String(bytes: readBuffer[..<bytesRead], encoding: .utf8) {
                    logger.log("RX: \(response.replacingOccurrences(of: "\r", with: " | ").trimmingCharacters(in: .whitespaces))", category: .response)
                    parseResponse(response)
                }
            }
        }
        updateWidgetStatus()
        updateLiveActivity()
    }

    private func updateWidgetStatus() {
        guard let receiver else { return }
        ReceiverStatus(
            receiverName: receiver.name,
            ipAddress: receiver.ipAddress,
            port: receiver.port,
            isPowerOn: state.isPowerOn,
            volume: state.volume,
            currentInput: state.currentInput,
            lastUpdated: .now
        ).save()
        WidgetCenter.shared.reloadTimelines(ofKind: "ReceiverStatusWidget")
    }

    private func updateLiveActivity() {
        guard let receiver, isConnected, isNetworkSource else {
            // End activity if not connected or not on a network source
            if liveActivity.isActive && (!isConnected || !isNetworkSource) {
                liveActivity.end()
            }
            return
        }
        liveActivity.update(
            receiverName: receiver.name,
            inputSource: state.currentInput,
            trackName: state.nowPlaying.line3,
            artistName: state.nowPlaying.line1,
            albumName: state.nowPlaying.line2,
            isPlaying: state.isPowerOn && !state.nowPlaying.isEmpty,
            volume: state.volume
        )
    }

    private func parseResponse(_ response: String) {
        parseResponseImpl(response)
    }

    /// Parses a raw Denon protocol response string and updates state.
    /// Also used directly in unit tests.
    func parseResponseForTesting(_ response: String) {
        parseResponseImpl(response)
    }

    private func parseResponseImpl(_ response: String) {
        let lines = response.components(separatedBy: "\r")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Zone 3 (check before Zone 2 since Z3 is a longer prefix)
            if trimmed.hasPrefix("Z3") {
                parseZone3Response(trimmed)
            }
            // Zone 2
            else if trimmed.hasPrefix("Z2") {
                parseZone2Response(trimmed)
            }
            // Now Playing (NSE lines)
            else if trimmed.hasPrefix("NSE") {
                parseNowPlayingResponse(trimmed)
            }
            // Sleep Timer
            else if trimmed.hasPrefix("SLP") {
                parseSleepTimerResponse(trimmed)
            }
            // Parameter Settings (tone, dynamic volume/EQ)
            else if trimmed.hasPrefix("PS") {
                parseParameterResponse(trimmed)
            }
            // Receiver Info
            else if trimmed.hasPrefix("SSINFAI") {
                parseReceiverInfoResponse(trimmed)
            }
            // Main zone
            else if trimmed.hasPrefix("PWON") {
                state.isPowerOn = true
            } else if trimmed.hasPrefix("PWSTANDBY") {
                state.isPowerOn = false
            } else if trimmed.hasPrefix("MV") && !trimmed.hasPrefix("MVMAX") {
                let volumeStr = trimmed.replacingOccurrences(of: "MV", with: "")
                if let volume = Int(volumeStr) {
                    state.volume = volume
                }
            } else if trimmed.hasPrefix("MUON") {
                state.isMuted = true
            } else if trimmed.hasPrefix("MUOFF") {
                state.isMuted = false
            } else if trimmed.hasPrefix("SI") {
                state.currentInput = trimmed.replacingOccurrences(of: "SI", with: "")
            } else if trimmed.hasPrefix("MS") {
                state.surroundMode = trimmed.replacingOccurrences(of: "MS", with: "")
            }
        }
    }

    private func parseZone2Response(_ line: String) {
        if line == "Z2ON" {
            state.zone2.isPowerOn = true
        } else if line == "Z2OFF" {
            state.zone2.isPowerOn = false
        } else if line.hasPrefix("Z2MUON") {
            state.zone2.isMuted = true
        } else if line.hasPrefix("Z2MUOFF") {
            state.zone2.isMuted = false
        } else if line.count >= 4 {
            // Check if it's a volume response (Z2XX where XX is digits)
            let afterPrefix = String(line.dropFirst(2))
            if let volume = Int(afterPrefix), afterPrefix.allSatisfy(\.isNumber) {
                state.zone2.volume = volume
            } else if !afterPrefix.hasPrefix("MU") {
                // It's an input source response
                state.zone2.currentInput = afterPrefix
            }
        }
    }

    private func parseZone3Response(_ line: String) {
        if line == "Z3ON" {
            state.zone3.isPowerOn = true
        } else if line == "Z3OFF" {
            state.zone3.isPowerOn = false
        } else if line.hasPrefix("Z3MUON") {
            state.zone3.isMuted = true
        } else if line.hasPrefix("Z3MUOFF") {
            state.zone3.isMuted = false
        } else if line.count >= 4 {
            let afterPrefix = String(line.dropFirst(2))
            if let volume = Int(afterPrefix), afterPrefix.allSatisfy(\.isNumber) {
                state.zone3.volume = volume
            } else if !afterPrefix.hasPrefix("MU") {
                state.zone3.currentInput = afterPrefix
            }
        }
    }

    private func parseNowPlayingResponse(_ line: String) {
        // NSE0 = playback status, NSE1-4 = display lines
        if line.hasPrefix("NSE1") {
            state.nowPlaying.line1 = String(line.dropFirst(4))
        } else if line.hasPrefix("NSE2") {
            state.nowPlaying.line2 = String(line.dropFirst(4))
        } else if line.hasPrefix("NSE3") {
            state.nowPlaying.line3 = String(line.dropFirst(4))
        } else if line.hasPrefix("NSE4") {
            state.nowPlaying.line4 = String(line.dropFirst(4))
        }
    }

    private func parseSleepTimerResponse(_ line: String) {
        // SLPOFF or SLP030, SLP060, SLP090, SLP120
        let value = line.replacingOccurrences(of: "SLP", with: "")
        if value == "OFF" {
            state.sleepTimer = nil
        } else if let minutes = Int(value) {
            state.sleepTimer = minutes
        }
    }

    private func parseParameterResponse(_ line: String) {
        if line.hasPrefix("PSBAS") {
            let value = line.replacingOccurrences(of: "PSBAS ", with: "")
            if let bass = Int(value) {
                state.bass = bass
            }
        } else if line.hasPrefix("PSTRE") {
            let value = line.replacingOccurrences(of: "PSTRE ", with: "")
            if let treble = Int(value) {
                state.treble = treble
            }
        } else if line.hasPrefix("PSDYNVOL") {
            let value = line.replacingOccurrences(of: "PSDYNVOL ", with: "")
            state.dynamicVolume = value
        } else if line.hasPrefix("PSDYNEQ") {
            let value = line.replacingOccurrences(of: "PSDYNEQ ", with: "")
            state.dynamicEQ = (value == "ON")
        }
    }

    private func parseReceiverInfoResponse(_ line: String) {
        // SSINFAISMD <model> or SSINFAISFSV <firmware>
        if line.hasPrefix("SSINFAISMD ") {
            state.receiverModel = line.replacingOccurrences(of: "SSINFAISMD ", with: "")
        } else if line.hasPrefix("SSINFAISFSV ") {
            state.firmwareVersion = line.replacingOccurrences(of: "SSINFAISFSV ", with: "")
        }
    }

    // MARK: - Control Methods

    func setPower(_ on: Bool) async throws {
        try await sendCommand(on ? "PWON" : "PWSTANDBY")
        state.isPowerOn = on
    }

    func setVolume(_ volume: Int) async throws {
        let clampedVolume = min(max(volume, 0), 98)
        let volumeString = String(format: "%02d", clampedVolume)
        try await sendCommand("MV\(volumeString)")
        state.volume = clampedVolume
    }

    func volumeUp() async throws {
        try await sendCommand("MVUP")
        try await Task.sleep(for: .milliseconds(200))
        try await sendCommand("MV?")
        try await Task.sleep(for: .milliseconds(100))
        readResponses()
    }

    func volumeDown() async throws {
        try await sendCommand("MVDOWN")
        try await Task.sleep(for: .milliseconds(200))
        try await sendCommand("MV?")
        try await Task.sleep(for: .milliseconds(100))
        readResponses()
    }

    func setMute(_ muted: Bool) async throws {
        try await sendCommand(muted ? "MUON" : "MUOFF")
        state.isMuted = muted
    }

    func setInput(_ input: String) async throws {
        try await sendCommand("SI\(input)")
        state.currentInput = input
        if !DenonConstants.networkInputs.contains(input) {
            liveActivity.end()
        }
    }

    // MARK: - Surround Mode

    func setSurroundMode(_ mode: String) async throws {
        try await sendCommand("MS\(mode)")
        state.surroundMode = mode
    }

    func querySurroundMode() async throws {
        try await sendCommand("MS?")
        try await Task.sleep(for: .milliseconds(300))
        readResponses()
    }

    // MARK: - Zone 2 Controls

    func setZone2Power(_ on: Bool) async throws {
        try await sendCommand(on ? "Z2ON" : "Z2OFF")
        state.zone2.isPowerOn = on
    }

    func setZone2Volume(_ volume: Int) async throws {
        let clamped = min(max(volume, 0), 98)
        let volumeString = String(format: "%02d", clamped)
        try await sendCommand("Z2\(volumeString)")
        state.zone2.volume = clamped
    }

    func zone2VolumeUp() async throws {
        try await sendCommand("Z2UP")
        try await Task.sleep(for: .milliseconds(200))
        try await sendCommand("Z2?")
        try await Task.sleep(for: .milliseconds(100))
        readResponses()
    }

    func zone2VolumeDown() async throws {
        try await sendCommand("Z2DOWN")
        try await Task.sleep(for: .milliseconds(200))
        try await sendCommand("Z2?")
        try await Task.sleep(for: .milliseconds(100))
        readResponses()
    }

    func setZone2Mute(_ muted: Bool) async throws {
        try await sendCommand(muted ? "Z2MUON" : "Z2MUOFF")
        state.zone2.isMuted = muted
    }

    func setZone2Input(_ input: String) async throws {
        try await sendCommand("Z2\(input)")
        state.zone2.currentInput = input
    }

    func refreshZone2State() async throws {
        try await sendCommand("Z2?")
        try await sendCommand("Z2MU?")
        try await Task.sleep(for: .milliseconds(500))
        readResponses()
    }

    // MARK: - Zone 3 Controls

    func setZone3Power(_ on: Bool) async throws {
        try await sendCommand(on ? "Z3ON" : "Z3OFF")
        state.zone3.isPowerOn = on
    }

    func setZone3Volume(_ volume: Int) async throws {
        let clamped = min(max(volume, 0), 98)
        let volumeString = String(format: "%02d", clamped)
        try await sendCommand("Z3\(volumeString)")
        state.zone3.volume = clamped
    }

    func zone3VolumeUp() async throws {
        try await sendCommand("Z3UP")
        try await Task.sleep(for: .milliseconds(200))
        try await sendCommand("Z3?")
        try await Task.sleep(for: .milliseconds(100))
        readResponses()
    }

    func zone3VolumeDown() async throws {
        try await sendCommand("Z3DOWN")
        try await Task.sleep(for: .milliseconds(200))
        try await sendCommand("Z3?")
        try await Task.sleep(for: .milliseconds(100))
        readResponses()
    }

    func setZone3Mute(_ muted: Bool) async throws {
        try await sendCommand(muted ? "Z3MUON" : "Z3MUOFF")
        state.zone3.isMuted = muted
    }

    func setZone3Input(_ input: String) async throws {
        try await sendCommand("Z3\(input)")
        state.zone3.currentInput = input
    }

    func refreshZone3State() async throws {
        try await sendCommand("Z3?")
        try await sendCommand("Z3MU?")
        try await Task.sleep(for: .milliseconds(500))
        readResponses()
    }

    // MARK: - Now Playing

    func refreshNowPlaying() async throws {
        try await sendCommand("NSE")
        try await Task.sleep(for: .milliseconds(500))
        readResponses()
    }

    // MARK: - Sleep Timer

    func setSleepTimer(_ value: String) async throws {
        try await sendCommand("SLP\(value)")
        if value == "OFF" {
            state.sleepTimer = nil
        } else if let minutes = Int(value) {
            state.sleepTimer = minutes
        }
    }

    func querySleepTimer() async throws {
        try await sendCommand("SLP?")
        try await Task.sleep(for: .milliseconds(300))
        readResponses()
    }

    // MARK: - Tone / EQ Controls

    /// Set bass level. Raw protocol value: 44 (-6 dB) to 56 (+6 dB), 50 = 0 dB.
    func setBass(_ value: Int) async throws {
        let clamped = min(max(value, 44), 56)
        try await sendCommand("PSBAS \(String(format: "%02d", clamped))")
        state.bass = clamped
    }

    /// Set treble level. Raw protocol value: 44 (-6 dB) to 56 (+6 dB), 50 = 0 dB.
    func setTreble(_ value: Int) async throws {
        let clamped = min(max(value, 44), 56)
        try await sendCommand("PSTRE \(String(format: "%02d", clamped))")
        state.treble = clamped
    }

    func queryToneControls() async throws {
        try await sendCommand("PSBAS ?")
        try await sendCommand("PSTRE ?")
        try await Task.sleep(for: .milliseconds(300))
        readResponses()
    }

    // MARK: - Dynamic Volume / Dynamic EQ

    func setDynamicVolume(_ mode: String) async throws {
        try await sendCommand("PSDYNVOL \(mode)")
        state.dynamicVolume = mode
    }

    func setDynamicEQ(_ enabled: Bool) async throws {
        try await sendCommand("PSDYNEQ \(enabled ? "ON" : "OFF")")
        state.dynamicEQ = enabled
    }

    func queryDynamicSettings() async throws {
        try await sendCommand("PSDYNVOL ?")
        try await sendCommand("PSDYNEQ ?")
        try await Task.sleep(for: .milliseconds(300))
        readResponses()
    }

    // MARK: - Tuner Presets

    func tunerPresetUp() async throws {
        try await sendCommand("TPANUP")
    }

    func tunerPresetDown() async throws {
        try await sendCommand("TPANDOWN")
    }

    /// Returns true if the current input is the tuner.
    var isTunerActive: Bool {
        state.currentInput == "TUNER"
    }

    // MARK: - Receiver Info

    func queryReceiverInfo() async throws {
        try await sendCommand("SSINFAISMD ?")
        try await sendCommand("SSINFAISFSV ?")
        try await Task.sleep(for: .milliseconds(500))
        readResponses()
    }

    // MARK: - Transport Controls (Network Sources)

    func transportPlay() async throws {
        try await sendCommand("NS9A")
    }

    func transportPause() async throws {
        try await sendCommand("NS9B")
    }

    func transportStop() async throws {
        try await sendCommand("NS9C")
    }

    func transportSkipNext() async throws {
        try await sendCommand("NS9D")
    }

    func transportSkipPrevious() async throws {
        try await sendCommand("NS9E")
    }
}

// MARK: - Computed Properties

extension DenonAPI {
    /// Returns true if the current input is a network-based source that may support now playing.
    var isNetworkSource: Bool {
        DenonConstants.networkInputs.contains(state.currentInput)
    }
}

// MARK: - Errors

enum DenonError: LocalizedError {
    case connectionFailed
    case connectionTimeout
    case connectionRefused
    case notConnected
    case disconnected
    case commandFailed

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to receiver"
        case .connectionTimeout:
            return "Connection timed out"
        case .connectionRefused:
            return "Connection refused by receiver"
        case .notConnected:
            return "Not connected to receiver"
        case .disconnected:
            return "Disconnected from receiver"
        case .commandFailed:
            return "Failed to send command"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed, .connectionRefused:
            return "Check that the receiver is powered on and the IP address is correct."
        case .connectionTimeout:
            return "The receiver did not respond. Verify it is on the same network and reachable."
        case .notConnected:
            return "Tap Connect to establish a connection first."
        case .disconnected:
            return "The connection was lost. Try reconnecting."
        case .commandFailed:
            return "The command could not be sent. Try again or reconnect."
        }
    }
}
