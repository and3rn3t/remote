//
//  DenonAPI.swift
//  remote
//
//  Created by Matt on 3/7/26.
//

import Foundation
import Network
import Observation
import SharedModels
import WidgetKit
import ActivityKit

/// State for a single zone (Main, Zone 2, or Zone 3).
///
/// Tracks the power, volume, mute, and input state for an individual audio zone.
/// Denon receivers support up to three zones with independent control.
struct ZoneState {
    /// Whether the zone is powered on.
    var isPowerOn: Bool = false

    /// Volume level for this zone (0-98, representing 0.0 to 98.0 dB).
    var volume: Int = 0

    /// Whether the zone audio is muted.
    var isMuted: Bool = false

    /// Current input source code (e.g., "BD", "GAME", "TV").
    var currentInput: String = "Unknown"
}

/// Now Playing information from network sources.
///
/// Tracks metadata for currently playing media on network-connected sources
/// (Spotify, Bluetooth, USB, NET, Media Player). The receiver provides up to
/// four lines of text (NSE1-NSE4) which typically contain artist, album, track, and extra info.
struct NowPlayingInfo {
    /// First line of metadata (typically artist name).
    var line1: String = ""

    /// Second line of metadata (typically album name).
    var line2: String = ""

    /// Third line of metadata (typically track title).
    var line3: String = ""

    /// Fourth line of metadata (extra info, format, etc.).
    var line4: String = ""

    /// Returns `true` if all metadata lines are empty.
    var isEmpty: Bool {
        line1.isEmpty && line2.isEmpty && line3.isEmpty && line4.isEmpty
    }
}

/// Represents the complete current state of the Denon AVR.
///
/// This structure holds all observable state for the receiver including:
/// - Main zone power, volume, input, and surround mode
/// - Zone 2 and Zone 3 states
/// - Now Playing metadata
/// - Tone controls and dynamic audio settings
/// - Sleep timer status
/// - Receiver hardware info
struct DenonState {
    /// Whether the main zone is powered on.
    var isPowerOn: Bool = false

    /// Main zone volume (0-98, representing 0.0 to 98.0 dB).
    var volume: Int = 0

    /// Whether the main zone is muted.
    var isMuted: Bool = false

    /// Current input source code (e.g., "BD", "GAME", "TV").
    var currentInput: String = "Unknown"

    /// Current surround sound mode (e.g., "STEREO", "DOLBY DIGITAL").
    var surroundMode: String = "Unknown"

    /// State for Zone 2 (secondary audio zone).
    var zone2 = ZoneState()

    /// State for Zone 3 (tertiary audio zone).
    var zone3 = ZoneState()

    /// Now Playing metadata from network sources.
    var nowPlaying = NowPlayingInfo()

    /// Sleep timer remaining minutes (`nil` if timer is off).
    var sleepTimer: Int?

    /// Bass control (44-56, where 50 = 0 dB, ±6 dB range).
    var bass: Int = 50

    /// Treble control (44-56, where 50 = 0 dB, ±6 dB range).
    var treble: Int = 50

    /// Dynamic Volume mode: "OFF", "LIT", "MED", or "HEV".
    var dynamicVolume: String = "OFF"

    /// Whether Dynamic EQ is enabled.
    var dynamicEQ: Bool = false

    /// Receiver model name (if queried).
    var receiverModel: String = ""

    /// Receiver firmware version (if queried).
    var firmwareVersion: String = ""

    /// Custom input aliases set on the receiver (e.g., "SAT/CBL" → "PS5").
    /// Populated by querying `SSFUN ?` on connect. Falls back to built-in names when empty.
    var inputAliases: [String: String] = [:]
}

/// Manages communication with Denon AVR via the network API.
///
/// `DenonAPI` is the core TCP client that handles:
/// - Connection establishment and automatic reconnection
/// - Command sending with throttling (50ms minimum between commands)
/// - Asynchronous response parsing from the receiver's protocol stream
/// - State updates via Swift Observation (`@Observable`)
/// - Integration with widgets, Live Activities, and connection logging
///
/// ## Usage
///
/// ```swift
/// let api = DenonAPI()
/// try await api.connect(to: receiver)
/// try await api.setPower(on: true)
/// try await api.setVolume(45)
/// ```
///
/// ## Thread Safety
///
/// This class must be used on the main actor. All public methods and properties
/// are `@MainActor` isolated to ensure thread-safe UI updates.
///
/// ## Protocol Details
///
/// Commands are sent over TCP port 23 (telnet), terminated with `\r`.
/// Responses arrive asynchronously and are parsed in a continuous stream.
/// The receiver does not send explicit acknowledgments for all commands.
@MainActor @Observable
final class DenonAPI {
    /// Current receiver state (power, volume, input, zones, etc.).
    var state = DenonState()

    /// Whether the TCP connection is active.
    var isConnected = false

    /// User-facing error message (nil if no error).
    var errorMessage: String?

    /// Whether the API is currently attempting to reconnect.
    var isReconnecting = false

    /// Current reconnection attempt number (for UI feedback).
    var currentReconnectAttempt = 0

    private var receiver: DenonReceiver?
    private var connection: NWConnection?
    private var readBuffer = [UInt8](repeating: 0, count: DenonConstants.readBufferSize)
    private var receiveBuffer = Data()
    private var receiveTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let logger = ConnectionLogger.shared
    private let liveActivity = LiveActivityManager.shared
    private var updateCoalesceTask: Task<Void, Never>?
    private var lastCommandTime: ContinuousClock.Instant?
    private let tcpQueue = DispatchQueue(label: "dev.andernet.remote.tcp")

    /// Timeout for establishing a TCP connection, in seconds (default: 5.0).
    var connectionTimeout: TimeInterval = DenonConstants.connectionTimeout

    // MARK: - Connection Management

    func connect(to receiver: DenonReceiver) async throws {
        self.receiver = receiver
        reconnectAttempts = 0

        // Restore cached state for instant UI while connecting
        restoreCachedState()

        logger.log("Connecting to \(receiver.name) at \(receiver.ipAddress):\(receiver.port)", category: .connection)
        try await establishConnection(to: receiver)
    }

    /// Loads the last-known receiver state from the shared App Group cache.
    private func restoreCachedState() {
        guard let cached = ReceiverStatus.load(),
              let receiver,
              cached.ipAddress == receiver.ipAddress else { return }

        state.isPowerOn = cached.isPowerOn
        state.volume = cached.volume
        state.currentInput = cached.currentInput
        logger.log("Restored cached state (last updated \(cached.lastUpdated))", category: .info)
    }

    private func establishConnection(to receiver: DenonReceiver) async throws {
        let nwConnection = NWConnection(
            host: NWEndpoint.Host(receiver.ipAddress),
            port: NWEndpoint.Port(integerLiteral: UInt16(receiver.port)),
            using: .tcp
        )
        self.connection = nwConnection

        // Await the connection reaching .ready (or failing) with a timeout.
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    let flag = OnceFlag()
                    nwConnection.stateUpdateHandler = { @Sendable state in
                        switch state {
                        case .ready:
                            flag.runOnce { cont.resume() }
                        case .failed(let error):
                            flag.runOnce { cont.resume(throwing: error) }
                        case .cancelled:
                            flag.runOnce { cont.resume(throwing: DenonError.connectionRefused) }
                        default:
                            break
                        }
                    }
                    nwConnection.start(queue: self.tcpQueue)
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(self.connectionTimeout))
                throw DenonError.connectionTimeout
            }
            // First to finish (success or failure) wins; cancel the other.
            do {
                try await group.next()
                group.cancelAll()
            } catch {
                group.cancelAll()
                nwConnection.cancel()
                self.connection = nil
                throw error
            }
        }

        isConnected = true
        errorMessage = nil
        logger.log("Connected successfully", category: .connection)

        // Install the post-connection state handler to detect unexpected disconnects.
        // This replaces the setup-phase handler used above to await .ready.
        nwConnection.stateUpdateHandler = { @Sendable [weak self] state in
            Task { @MainActor [weak self] in
                guard let self, self.isConnected else { return }
                switch state {
                case .failed(let error):
                    self.isConnected = false
                    self.errorMessage = error.localizedDescription
                    self.logger.log("Connection lost: \(error.localizedDescription)", category: .error)
                    await self.attemptReconnect()
                case .cancelled:
                    // Cancellation is expected on user-initiated disconnect; ignore.
                    break
                default:
                    break
                }
            }
        }

        // Start continuous receive loop
        startReceiving()

        // Initial state refresh runs in a detached task so it doesn't block
        // the caller and doesn't queue ahead of immediate user commands.
        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(DenonConstants.postStepDelayMilliseconds))
            do {
                try await self.refreshState()
            } catch {
                self.logger.log("Initial state refresh failed (non-fatal): \(error.localizedDescription)", category: .error)
            }
        }
    }

    func disconnect() {
        logger.log("Disconnecting", category: .connection)
        receiveTask?.cancel()
        receiveTask = nil
        connection?.cancel()
        connection = nil
        isConnected = false
        reconnectAttempts = 0
        receiveBuffer.removeAll()
        liveActivity.end()
    }

    private func cleanupConnection() {
        receiveTask?.cancel()
        receiveTask = nil
        connection?.cancel()
        connection = nil
        receiveBuffer.removeAll()
    }

    // MARK: - Connection Monitoring & Reconnection

    private func startReceiving() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self, let connection = self.connection else { return }
            while !Task.isCancelled {
                var shouldStop = false
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    connection.receive(
                        minimumIncompleteLength: 1,
                        maximumLength: DenonConstants.readBufferSize
                    ) { @Sendable [weak self] data, _, isComplete, error in
                        Task { @MainActor [weak self] in
                            guard let self else { cont.resume(); return }
                            if let data, !data.isEmpty {
                                self.receiveBuffer.append(data)
                                self.drainReceiveBuffer()
                            }
                            if let error {
                                self.logger.log("Receive error: \(error.localizedDescription)", category: .error)
                            }
                            if isComplete {
                                // TCP stream ended cleanly; stateUpdateHandler will fire .failed/.cancelled
                                shouldStop = true
                            }
                            cont.resume()
                        }
                    }
                }
                if shouldStop || Task.isCancelled { break }
            }
        }
    }

    /// Parses all complete `\r`-terminated lines out of `receiveBuffer`.
    private func drainReceiveBuffer() {
        while let crIndex = receiveBuffer.firstIndex(of: UInt8(ascii: "\r")) {
            let lineData = receiveBuffer[receiveBuffer.startIndex..<crIndex]
            if let line = String(bytes: lineData, encoding: .utf8), !line.isEmpty {
                logger.log("RX: \(line)", category: .response)
                parseResponse(line)
            }
            receiveBuffer.removeSubrange(receiveBuffer.startIndex...crIndex)
        }
        scheduleCoalescedUpdate()
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

        // Exponential backoff with jitter: ~1s, ~2s, ~4s, ~8s, ~16s
        let baseDelay = pow(2.0, Double(reconnectAttempts - 1))
        let jitter = Double.random(in: 0..<(baseDelay * 0.25))
        try? await Task.sleep(for: .seconds(baseDelay + jitter))

        guard !Task.isCancelled else {
            isReconnecting = false
            return
        }

        cleanupConnection()

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
        guard isConnected, let connection else {
            throw DenonError.notConnected
        }

        // Throttle: ensure minimum interval between commands
        if let last = lastCommandTime {
            let elapsed = ContinuousClock.now - last
            let minInterval = Duration.milliseconds(DenonConstants.commandThrottleMilliseconds)
            if elapsed < minInterval {
                try await Task.sleep(for: minInterval - elapsed)
            }
        }

        let data = Data("\(command)\r".utf8)
        logger.log("TX: \(command)", category: .command)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let flag = OnceFlag()
            connection.send(content: data, completion: .contentProcessed { @Sendable error in
                if let error {
                    flag.runOnce { cont.resume(throwing: error) }
                } else {
                    flag.runOnce { cont.resume() }
                }
            })
        }

        lastCommandTime = .now

        // Brief delay to allow receiver to process
        try await Task.sleep(for: .milliseconds(DenonConstants.postCommandDelayMilliseconds))
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
        try await sendCommand("SSFUN ?")

        // Allow time for responses to arrive and be processed by the receive loop
        try await Task.sleep(for: .milliseconds(DenonConstants.bulkQueryResponseDelayMilliseconds))
    }

    private func readResponses() {
        // No-op: responses are now handled continuously by startReceiving() / drainReceiveBuffer()
    }

    /// Batches widget and live activity updates so rapid responses don't trigger excessive reloads.
    private func scheduleCoalescedUpdate() {
        updateCoalesceTask?.cancel()
        updateCoalesceTask = Task {
            try? await Task.sleep(for: .milliseconds(DenonConstants.widgetUpdateCoalesceMilliseconds))
            guard !Task.isCancelled else { return }
            updateWidgetStatus()
            updateLiveActivity()
        }
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
                parseZoneResponse(trimmed, prefix: "Z3", zone: \.zone3)
            }
            // Zone 2
            else if trimmed.hasPrefix("Z2") {
                parseZoneResponse(trimmed, prefix: "Z2", zone: \.zone2)
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
            // Input aliases
            else if trimmed.hasPrefix("SSFUN") {
                parseInputAliasResponse(trimmed)
            }
            // Main zone
            else if trimmed.hasPrefix("PWON") {
                state.isPowerOn = true
            } else if trimmed.hasPrefix("PWSTANDBY") {
                state.isPowerOn = false
            } else if trimmed.hasPrefix("MV") && !trimmed.hasPrefix("MVMAX") {
                let volumeStr = trimmed.replacingOccurrences(of: "MV", with: "")
                if volumeStr.count == 3 {
                    // Half-step (e.g. "525" = 52.5 dB): round up so UI stays
                    // consistent with the optimistic +1 update.
                    let base = Int(volumeStr.prefix(2)) ?? 0
                    state.volume = volumeStr.last == "5" ? base + 1 : base
                } else if let volume = Int(volumeStr) {
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

    /// Generic parser for zone responses (Z2/Z3).
    private func parseZoneResponse(_ line: String, prefix: String, zone: WritableKeyPath<DenonState, ZoneState>) {
        if line == "\(prefix)ON" {
            state[keyPath: zone].isPowerOn = true
        } else if line == "\(prefix)OFF" {
            state[keyPath: zone].isPowerOn = false
        } else if line.hasPrefix("\(prefix)MUON") {
            state[keyPath: zone].isMuted = true
        } else if line.hasPrefix("\(prefix)MUOFF") {
            state[keyPath: zone].isMuted = false
        } else if line.count >= prefix.count + 2 {
            let afterPrefix = String(line.dropFirst(prefix.count))
            if let volume = Int(afterPrefix), afterPrefix.allSatisfy(\.isNumber) {
                state[keyPath: zone].volume = min(max(volume, 0), DenonConstants.maxVolume)
            } else if !afterPrefix.hasPrefix("MU") {
                state[keyPath: zone].currentInput = afterPrefix
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

    private func parseInputAliasResponse(_ line: String) {
        // Response format varies by firmware: "SSFUNSAT/CBL PS5" or "SSFUN SAT/CBL PS5"
        // Drop the 5-char "SSFUN" prefix then trim any leading space to handle both.
        let body = String(line.dropFirst("SSFUN".count)).trimmingCharacters(in: .whitespaces)
        // Match against known input codes, longest first to avoid ambiguous prefix matches.
        let sortedCodes = DenonInputs.all.map(\.code).sorted { $0.count > $1.count }
        for code in sortedCodes where body.hasPrefix(code) {
            let alias = String(body.dropFirst(code.count)).trimmingCharacters(in: .whitespaces)
            if !alias.isEmpty {
                state.inputAliases[code] = alias
            }
            return
        }
    }

    // MARK: - Control Methods

    func setPower(_ on: Bool) async throws {
        try await sendCommand(on ? "PWON" : "PWSTANDBY")
        state.isPowerOn = on
    }

    func setVolume(_ volume: Int) async throws {
        let clampedVolume = min(max(volume, 0), 98)
        state.volume = clampedVolume
        let volumeString = String(format: "%02d", clampedVolume)
        try await sendCommand("MV\(volumeString)")
    }

    func volumeUp() async throws {
        state.volume = min(state.volume + 1, DenonConstants.maxVolume)
        try await sendCommand("MVUP")
        // Receiver automatically broadcasts the new MV value — no need to poll.
    }

    func volumeDown() async throws {
        state.volume = max(state.volume - 1, 0)
        try await sendCommand("MVDOWN")
        // Receiver automatically broadcasts the new MV value — no need to poll.
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
    }

    // MARK: - Zone Controls

    /// Identifies a secondary zone for zone-specific commands.
    enum Zone {
        case zone2, zone3

        var prefix: String {
            switch self {
            case .zone2: "Z2"
            case .zone3: "Z3"
            }
        }

        var keyPath: WritableKeyPath<DenonState, ZoneState> {
            switch self {
            case .zone2: \.zone2
            case .zone3: \.zone3
            }
        }
    }

    func setZonePower(_ on: Bool, zone: Zone) async throws {
        try await sendCommand(on ? "\(zone.prefix)ON" : "\(zone.prefix)OFF")
        state[keyPath: zone.keyPath].isPowerOn = on
    }

    func setZoneVolume(_ volume: Int, zone: Zone) async throws {
        let clamped = min(max(volume, 0), DenonConstants.maxVolume)
        let volumeString = String(format: "%02d", clamped)
        try await sendCommand("\(zone.prefix)\(volumeString)")
        state[keyPath: zone.keyPath].volume = clamped
    }

    func zoneVolumeUp(_ zone: Zone) async throws {
        try await zoneVolumeStep("UP", prefix: zone.prefix, zone: zone)
    }

    func zoneVolumeDown(_ zone: Zone) async throws {
        try await zoneVolumeStep("DOWN", prefix: zone.prefix, zone: zone)
    }

    func setZoneMute(_ muted: Bool, zone: Zone) async throws {
        try await sendCommand(muted ? "\(zone.prefix)MUON" : "\(zone.prefix)MUOFF")
        state[keyPath: zone.keyPath].isMuted = muted
    }

    func setZoneInput(_ input: String, zone: Zone) async throws {
        try await sendCommand("\(zone.prefix)\(input)")
        state[keyPath: zone.keyPath].currentInput = input
    }

    func refreshZoneState(_ zone: Zone) async throws {
        try await sendCommand("\(zone.prefix)?")
        try await sendCommand("\(zone.prefix)MU?")
    }

    private func zoneVolumeStep(_ direction: String, prefix: String, zone: Zone) async throws {
        let kp = zone.keyPath
        if direction == "UP" {
            state[keyPath: kp].volume = min(state[keyPath: kp].volume + 1, DenonConstants.maxVolume)
        } else {
            state[keyPath: kp].volume = max(state[keyPath: kp].volume - 1, 0)
        }
        try await sendCommand("\(prefix)\(direction)")
        // Receiver auto-broadcasts the new volume — no need to poll.
    }

    // MARK: - Now Playing

    func refreshNowPlaying() async throws {
        try await sendCommand("NSE")
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

// MARK: - OnceFlag

/// Ensures a closure is only executed once, safe to call from multiple concurrency contexts.
private final class OnceFlag: @unchecked Sendable {
    private var _done = false
    private let nslock = NSLock()
    nonisolated func runOnce(_ action: () -> Void) {
        nslock.lock()
        let should = !_done
        if should { _done = true }
        nslock.unlock()
        if should { action() }
    }
}
