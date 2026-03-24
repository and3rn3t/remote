//
//  DenonConstants.swift
//  remote
//

import Foundation

// MARK: - Protocol & App Constants

nonisolated enum DenonConstants {
    static let defaultPort = 23
    static let maxVolume = 98
    static let connectionTimeout: TimeInterval = 5.0
    static let intentTimeout: TimeInterval = 5.0
    static let maxReconnectAttempts = 5
    static let readBufferSize = 4096
    static let maxLogEntries = 500
    static let volumeDebounceMilliseconds = 150

    // Command timing (milliseconds)
    static let commandThrottleMilliseconds = 25
    static let postCommandDelayMilliseconds = 25
    static let postStepDelayMilliseconds = 150
    static let bulkQueryResponseDelayMilliseconds = 400
    static let widgetUpdateCoalesceMilliseconds = 200
    static let connectionPollIntervalMilliseconds = 100
    static let connectionMonitorIntervalSeconds = 10

    // Tone: raw protocol values 44–56, center = 50 = 0 dB
    static let toneMin = 44
    static let toneMax = 56
    static let toneCenter = 50

    /// Network-based input sources that may support now playing.
    static let networkInputs: Set<String> = ["NET", "SPOTIFY", "BT", "USB/IPOD", "MPLAY"]

    /// Converts raw tone value (44–56) to a dB label relative to center (50 = 0 dB).
    static func toneLabel(_ value: Int) -> String {
        let db = value - toneCenter
        if db > 0 { return "+\(db) dB" }
        if db < 0 { return "\(db) dB" }
        return "0 dB"
    }

    /// Converts raw subwoofer level (38–62) to a dB label relative to center (50 = 0 dB).
    static func subwooferLabel(_ value: Int) -> String {
        let db = value - 50
        if db > 0 { return "+\(db) dB" }
        if db < 0 { return "\(db) dB" }
        return "0 dB"
    }
}

// MARK: - Input Sources

enum DenonInputs {
    static let all: [(name: String, code: String)] = [
        ("Blu-ray", "BD"),
        ("Game", "GAME"),
        ("Media Player", "MPLAY"),
        ("TV Audio", "TV"),
        ("Cable/Sat", "SAT/CBL"),
        ("DVD", "DVD"),
        ("AUX1", "AUX1"),
        ("AUX2", "AUX2"),
        ("Tuner", "TUNER"),
        ("Bluetooth", "BT"),
        ("USB/iPod", "USB/IPOD"),
        ("Network", "NET"),
        ("Spotify", "SPOTIFY"),
    ]

    /// Human-readable display name for an input code.
    static func displayName(for code: String) -> String {
        all.first { $0.code == code }?.name ?? code
    }

    /// SF Symbol name for an input code.
    static func icon(for code: String) -> String {
        switch code {
        case "BD": return "opticaldiscdrive.fill"
        case "GAME": return "gamecontroller.fill"
        case "MPLAY": return "play.rectangle.fill"
        case "TV": return "tv.fill"
        case "SAT/CBL": return "square.stack.3d.up.fill"
        case "DVD": return "opticaldiscdrive"
        case "AUX1", "AUX2": return "cable.connector"
        case "TUNER": return "radio.fill"
        case "BT": return "bluetooth"
        case "USB/IPOD": return "ipod"
        case "NET": return "network"
        case "SPOTIFY": return "music.note"
        default: return "rectangle.fill"
        }
    }
}

// MARK: - Surround Modes

enum DenonSurroundModes {
    static let all: [(name: String, code: String)] = [
        ("Stereo", "STEREO"),
        ("Direct", "DIRECT"),
        ("Pure Direct", "PURE DIRECT"),
        ("Multi Ch Stereo", "MCH STEREO"),
        ("Dolby Digital", "DOLBY DIGITAL"),
        ("Dolby Surround", "DOLBY SURROUND"),
        ("Dolby Atmos", "DOLBY ATMOS"),
        ("DTS Surround", "DTS SURROUND"),
        ("DTS HD", "DTS HD"),
        ("DTS Neural:X", "NEURAL:X"),
        ("Multi Ch In", "MULTI CH IN"),
        ("Rock Arena", "ROCK ARENA"),
        ("Jazz Club", "JAZZ CLUB"),
        ("Mono Movie", "MONO MOVIE"),
        ("Matrix", "MATRIX"),
        ("Game", "GAME"),
        ("Virtual", "VIRTUAL"),
        ("Auto", "AUTO"),
    ]

    /// Human-readable display name for a surround mode code.
    static func displayName(for code: String) -> String {
        all.first { $0.code == code }?.name ?? code
    }
}

// MARK: - Dynamic Volume Options

enum DenonDynamicVolume {
    static let options: [(name: String, code: String)] = [
        ("Off", "OFF"),
        ("Light", "LIT"),
        ("Medium", "MED"),
        ("Heavy", "HEV"),
    ]
}

// MARK: - Sleep Timer Options

enum DenonSleepTimer {
    static let options: [(name: String, value: String)] = [
        ("Off", "OFF"),
        ("30 min", "030"),
        ("60 min", "060"),
        ("90 min", "090"),
        ("120 min", "120"),
    ]
}

// MARK: - Dialogue Enhancer Options

enum DenonDialogueEnhancer {
    static let options: [(name: String, code: String)] = [
        ("Off", "OFF"),
        ("Low", "LOW"),
        ("Medium", "MED"),
        ("High", "HI"),
    ]
}

// MARK: - Audyssey MultEQ Options

enum DenonMultEQ {
    static let options: [(name: String, code: String)] = [
        ("Off", "OFF"),
        ("Reference", "REFERENCE"),
        ("L1 (Byp.)", "L1"),
        ("L2 (Flat)", "L2"),
        ("Flat", "FLAT"),
    ]
}

// MARK: - Night Mode Options

enum DenonNightMode {
    static let options: [(name: String, code: String)] = [
        ("Off", "OFF"),
        ("Low", "LOW"),
        ("Mid", "MID"),
        ("High", "HI"),
    ]
}

// MARK: - Dimmer Options

enum DenonDimmer {
    static let options: [(name: String, code: String)] = [
        ("Bright", "BRI"),
        ("Dim", "DIM"),
        ("Dark", "DAR"),
        ("Off", "OFF"),
    ]
}

// MARK: - ECO Mode Options

enum DenonEcoMode {
    static let options: [(name: String, code: String)] = [
        ("Off", "OFF"),
        ("On", "ON"),
        ("Auto", "AUTO"),
    ]
}

// MARK: - Auto Standby Options

enum DenonAutoStandby {
    static let options: [(name: String, code: String)] = [
        ("Off", "OFF"),
        ("15 min", "15M"),
        ("30 min", "30M"),
        ("60 min", "60M"),
    ]
}

// MARK: - HDMI Monitor Output Options

enum DenonHDMIMonitor {
    static let options: [(name: String, code: String)] = [
        ("Auto", "AUTO"),
        ("HDMI 1", "1"),
        ("HDMI 2", "2"),
    ]
}

// MARK: - HDMI Resolution Options

enum DenonHDMIResolution {
    static let options: [(name: String, code: String)] = [
        ("Auto", "AUTO"),
        ("480p", "48P"),
        ("1080i", "10I"),
        ("720p", "72P"),
        ("1080p", "10P"),
        ("1080p:24Hz", "10P6"),
        ("4K", "4KF"),
    ]
}

// MARK: - Video Aspect Ratio Options

enum DenonVideoAspect {
    static let options: [(name: String, code: String)] = [
        ("Normal", "NRM"),
        ("Full", "FUL"),
    ]
}
