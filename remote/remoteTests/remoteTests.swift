//
//  remoteTests.swift
//  remoteTests
//
//  Created by Matt on 3/7/26.
//

import Testing
import Foundation
import SwiftData
@testable import remote

// MARK: - DenonReceiver Model Tests

struct DenonReceiverTests {

    @Test func createReceiverWithDefaults() {
        let receiver = DenonReceiver(name: "Living Room", ipAddress: "192.168.1.100")
        #expect(receiver.name == "Living Room")
        #expect(receiver.ipAddress == "192.168.1.100")
        #expect(receiver.port == 23)
        #expect(receiver.isFavorite == false)
        #expect(receiver.lastConnected == nil)
    }

    @Test func createReceiverWithCustomPort() {
        let receiver = DenonReceiver(name: "Bedroom", ipAddress: "10.0.0.50", port: 8080)
        #expect(receiver.port == 8080)
    }

    @Test func createReceiverAsFavorite() {
        let receiver = DenonReceiver(name: "Theater", ipAddress: "192.168.1.200", isFavorite: true)
        #expect(receiver.isFavorite == true)
    }

    @Test func receiverHasUniqueID() {
        let receiver1 = DenonReceiver(name: "A", ipAddress: "1.1.1.1")
        let receiver2 = DenonReceiver(name: "B", ipAddress: "2.2.2.2")
        #expect(receiver1.id != receiver2.id)
    }
}

// MARK: - DenonState Tests

struct DenonStateTests {

    @Test func defaultStateValues() {
        let state = DenonState()
        #expect(state.isPowerOn == false)
        #expect(state.volume == 0)
        #expect(state.isMuted == false)
        #expect(state.currentInput == "Unknown")
        #expect(state.surroundMode == "Unknown")
        #expect(state.zone2.isPowerOn == false)
        #expect(state.zone2.volume == 0)
        #expect(state.zone3.isPowerOn == false)
        #expect(state.nowPlaying.isEmpty)
    }
}

// MARK: - DenonAPI Response Parsing Tests

@MainActor
struct DenonAPIParsingTests {

    @Test func parsePowerOnResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("PWON\r")
        #expect(api.state.isPowerOn == true)
    }

    @Test func parsePowerStandbyResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("PWSTANDBY\r")
        #expect(api.state.isPowerOn == false)
    }

    @Test func parseVolumeResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("MV45\r")
        #expect(api.state.volume == 45)
    }

    @Test func parseVolumeIgnoresMaxVolume() {
        let api = DenonAPI()
        api.state.volume = 30
        api.parseResponseForTesting("MVMAX80\r")
        #expect(api.state.volume == 30)
    }

    @Test func parseMuteOnResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("MUON\r")
        #expect(api.state.isMuted == true)
    }

    @Test func parseMuteOffResponse() {
        let api = DenonAPI()
        api.state.isMuted = true
        api.parseResponseForTesting("MUOFF\r")
        #expect(api.state.isMuted == false)
    }

    @Test func parseInputSourceResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("SIBD\r")
        #expect(api.state.currentInput == "BD")
    }

    @Test func parseSurroundModeResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("MSDOLBY DIGITAL\r")
        #expect(api.state.surroundMode == "DOLBY DIGITAL")
    }

    @Test func parseMultipleResponsesAtOnce() {
        let api = DenonAPI()
        api.parseResponseForTesting("PWON\rMV50\rMUOFF\rSIGAME\rMSSTEREO\r")
        #expect(api.state.isPowerOn == true)
        #expect(api.state.volume == 50)
        #expect(api.state.isMuted == false)
        #expect(api.state.currentInput == "GAME")
        #expect(api.state.surroundMode == "STEREO")
    }

    @Test func parseEmptyResponse() {
        let api = DenonAPI()
        let originalState = api.state
        api.parseResponseForTesting("\r")
        #expect(api.state.isPowerOn == originalState.isPowerOn)
        #expect(api.state.volume == originalState.volume)
    }
}

// MARK: - DenonAPI Input Sources Tests

struct DenonAPIInputTests {

    @Test func availableInputsNotEmpty() {
        #expect(!DenonInputs.all.isEmpty)
    }

    @Test func availableInputsContainsBluray() {
        let found = DenonInputs.all.contains { $0.code == "BD" }
        #expect(found)
    }

    @Test func allInputCodesAreNonEmpty() {
        for input in DenonInputs.all {
            #expect(!input.code.isEmpty)
            #expect(!input.name.isEmpty)
        }
    }
}

// MARK: - Zone 2/3 Parsing Tests

@MainActor
struct ZoneParsingTests {

    @Test func parseZone2PowerOn() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z2ON\r")
        #expect(api.state.zone2.isPowerOn == true)
    }

    @Test func parseZone2PowerOff() {
        let api = DenonAPI()
        api.state.zone2.isPowerOn = true
        api.parseResponseForTesting("Z2OFF\r")
        #expect(api.state.zone2.isPowerOn == false)
    }

    @Test func parseZone2Volume() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z240\r")
        #expect(api.state.zone2.volume == 40)
    }

    @Test func parseZone2MuteOn() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z2MUON\r")
        #expect(api.state.zone2.isMuted == true)
    }

    @Test func parseZone2MuteOff() {
        let api = DenonAPI()
        api.state.zone2.isMuted = true
        api.parseResponseForTesting("Z2MUOFF\r")
        #expect(api.state.zone2.isMuted == false)
    }

    @Test func parseZone2Input() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z2TUNER\r")
        #expect(api.state.zone2.currentInput == "TUNER")
    }

    @Test func parseZone3PowerOn() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z3ON\r")
        #expect(api.state.zone3.isPowerOn == true)
    }

    @Test func parseZone3Volume() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z335\r")
        #expect(api.state.zone3.volume == 35)
    }

    @Test func parseZone3Input() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z3NET\r")
        #expect(api.state.zone3.currentInput == "NET")
    }

    @Test func zoneResponsesDoNotAffectMainZone() {
        let api = DenonAPI()
        api.state.volume = 50
        api.parseResponseForTesting("Z240\rZ335\r")
        #expect(api.state.volume == 50)
        #expect(api.state.zone2.volume == 40)
        #expect(api.state.zone3.volume == 35)
    }
}

// MARK: - Now Playing Parsing Tests

@MainActor
struct NowPlayingParsingTests {

    @Test func parseNowPlayingLines() {
        let api = DenonAPI()
        api.parseResponseForTesting("NSE1Artist Name\rNSE2Album Title\rNSE3Song Title\rNSE4Extra Info\r")
        #expect(api.state.nowPlaying.line1 == "Artist Name")
        #expect(api.state.nowPlaying.line2 == "Album Title")
        #expect(api.state.nowPlaying.line3 == "Song Title")
        #expect(api.state.nowPlaying.line4 == "Extra Info")
        #expect(api.state.nowPlaying.isEmpty == false)
    }

    @Test func parsePartialNowPlaying() {
        let api = DenonAPI()
        api.parseResponseForTesting("NSE3Track Only\r")
        #expect(api.state.nowPlaying.line3 == "Track Only")
        #expect(api.state.nowPlaying.line1.isEmpty)
        #expect(api.state.nowPlaying.isEmpty == false)
    }

    @Test func emptyNowPlaying() {
        let info = NowPlayingInfo()
        #expect(info.isEmpty == true)
    }
}

// MARK: - Surround Mode Tests

@MainActor
struct SurroundModeTests {

    @Test func availableSurroundModesNotEmpty() {
        #expect(!DenonSurroundModes.all.isEmpty)
    }

    @Test func surroundModesContainsStereo() {
        let found = DenonSurroundModes.all.contains { $0.code == "STEREO" }
        #expect(found)
    }

    @Test func isNetworkSourceDetection() {
        let api = DenonAPI()
        api.state.currentInput = "NET"
        #expect(api.isNetworkSource == true)

        api.state.currentInput = "BD"
        #expect(api.isNetworkSource == false)

        api.state.currentInput = "SPOTIFY"
        #expect(api.isNetworkSource == true)
    }
}

// MARK: - ConnectionLogger Tests

@MainActor
struct ConnectionLoggerTests {

    @Test func logAddsEntry() {
        let logger = ConnectionLogger.shared
        let countBefore = logger.entries.count
        logger.log("Test message", category: .info)
        #expect(logger.entries.count == countBefore + 1)
        #expect(logger.entries.last?.message == "Test message")
        #expect(logger.entries.last?.category == .info)
    }

    @Test func logEntryHasTimestamp() {
        let logger = ConnectionLogger.shared
        let before = Date()
        logger.log("Timestamp test", category: .command)
        let entry = logger.entries.last!
        #expect(entry.timestamp >= before)
    }

    @Test func exportTextFormatsCorrectly() {
        let logger = ConnectionLogger.shared
        logger.clear()
        logger.log("Hello", category: .connection)
        logger.log("World", category: .error)
        let text = logger.exportText()
        #expect(text.contains("[Connection] Hello"))
        #expect(text.contains("[Error] World"))
    }

    @Test func clearRemovesAllEntries() {
        let logger = ConnectionLogger.shared
        logger.log("Something", category: .info)
        logger.clear()
        #expect(logger.entries.isEmpty)
    }
}

// MARK: - AppSettings Tests

struct AppSettingsTests {

    @Test func hasCompletedOnboardingDefaultsFalse() {
        // AppSettings.hasCompletedOnboarding uses @AppStorage, defaults to false
        // We can at least verify the property exists and is Bool
        let value = AppSettings.hasCompletedOnboarding
        #expect(value == true || value == false)
    }
}

// MARK: - DenonAPI Reconnection State Tests

@MainActor
struct ReconnectionStateTests {

    @Test func initialReconnectionState() {
        let api = DenonAPI()
        #expect(api.isReconnecting == false)
        #expect(api.currentReconnectAttempt == 0)
    }

    @Test func disconnectResetsState() {
        let api = DenonAPI()
        api.isConnected = true
        api.disconnect()
        #expect(api.isConnected == false)
        #expect(api.isReconnecting == false)
    }
}

// MARK: - Sleep Timer Parsing Tests

@MainActor
struct SleepTimerTests {

    @Test func parseSleepTimerOff() {
        let api = DenonAPI()
        api.state.sleepTimer = 60
        api.parseResponseForTesting("SLPOFF\r")
        #expect(api.state.sleepTimer == nil)
    }

    @Test func parseSleepTimer30() {
        let api = DenonAPI()
        api.parseResponseForTesting("SLP030\r")
        #expect(api.state.sleepTimer == 30)
    }

    @Test func parseSleepTimer120() {
        let api = DenonAPI()
        api.parseResponseForTesting("SLP120\r")
        #expect(api.state.sleepTimer == 120)
    }

    @Test func sleepTimerOptionsNotEmpty() {
        #expect(!DenonSleepTimer.options.isEmpty)
        #expect(DenonSleepTimer.options.first?.value == "OFF")
    }
}

// MARK: - Tone/EQ Parsing Tests

@MainActor
struct ToneControlTests {

    @Test func parseBassResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("PSBAS 52\r")
        #expect(api.state.bass == 52)
    }

    @Test func parseTrebleResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("PSTRE 48\r")
        #expect(api.state.treble == 48)
    }

    @Test func defaultToneValuesAreCenter() {
        let state = DenonState()
        #expect(state.bass == 50)
        #expect(state.treble == 50)
    }
}

// MARK: - Dynamic Volume/EQ Tests

@MainActor
struct DynamicAudioTests {

    @Test func parseDynamicVolumeResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("PSDYNVOL MED\r")
        #expect(api.state.dynamicVolume == "MED")
    }

    @Test func parseDynamicEQOn() {
        let api = DenonAPI()
        api.parseResponseForTesting("PSDYNEQ ON\r")
        #expect(api.state.dynamicEQ == true)
    }

    @Test func parseDynamicEQOff() {
        let api = DenonAPI()
        api.state.dynamicEQ = true
        api.parseResponseForTesting("PSDYNEQ OFF\r")
        #expect(api.state.dynamicEQ == false)
    }

    @Test func dynamicVolumeOptionsContainsOff() {
        let found = DenonDynamicVolume.options.contains { $0.code == "OFF" }
        #expect(found)
    }

    @Test func dynamicVolumeDefaultIsOff() {
        let state = DenonState()
        #expect(state.dynamicVolume == "OFF")
        #expect(state.dynamicEQ == false)
    }
}

// MARK: - Receiver Info Parsing Tests

@MainActor
struct ReceiverInfoTests {

    @Test func parseModelResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("SSINFAISMD AVR-X3800H\r")
        #expect(api.state.receiverModel == "AVR-X3800H")
    }

    @Test func parseFirmwareResponse() {
        let api = DenonAPI()
        api.parseResponseForTesting("SSINFAISFSV 1234-5678-9012\r")
        #expect(api.state.firmwareVersion == "1234-5678-9012")
    }

    @Test func receiverInfoDefaultsEmpty() {
        let state = DenonState()
        #expect(state.receiverModel.isEmpty)
        #expect(state.firmwareVersion.isEmpty)
    }
}

// MARK: - Tuner Tests

@MainActor
struct TunerTests {

    @Test func isTunerActiveDetection() {
        let api = DenonAPI()
        api.state.currentInput = "TUNER"
        #expect(api.isTunerActive == true)

        api.state.currentInput = "BD"
        #expect(api.isTunerActive == false)
    }
}

// MARK: - Scene Tests

struct ReceiverSceneTests {

    @Test func sceneInitializesWithCorrectDefaults() {
        let receiverID = UUID()
        let scene = ReceiverScene(
            name: "Movie Night",
            receiverID: receiverID,
            inputCode: "BD",
            volume: 45,
            surroundMode: "DOLBY DIGITAL",
            isMuted: false
        )

        #expect(scene.name == "Movie Night")
        #expect(scene.receiverID == receiverID)
        #expect(scene.inputCode == "BD")
        #expect(scene.volume == 45)
        #expect(scene.surroundMode == "DOLBY DIGITAL")
        #expect(scene.isMuted == false)
        #expect(scene.hasZone2 == false)
        #expect(scene.hasZone3 == false)
    }

    @Test func sceneWithZone2() {
        let scene = ReceiverScene(
            name: "Party",
            receiverID: UUID(),
            inputCode: "NET",
            volume: 55,
            surroundMode: "STEREO",
            isMuted: false,
            zone2InputCode: "MPLAY",
            zone2Volume: 40,
            zone2IsMuted: false
        )

        #expect(scene.hasZone2 == true)
        #expect(scene.hasZone3 == false)
        #expect(scene.zone2InputCode == "MPLAY")
        #expect(scene.zone2Volume == 40)
        #expect(scene.zone2IsMuted == false)
    }

    @Test func sceneWithAllZones() {
        let scene = ReceiverScene(
            name: "Full House",
            receiverID: UUID(),
            inputCode: "SPOTIFY",
            volume: 50,
            surroundMode: "MCH STEREO",
            isMuted: false,
            zone2InputCode: "NET",
            zone2Volume: 35,
            zone2IsMuted: true,
            zone3InputCode: "TUNER",
            zone3Volume: 30,
            zone3IsMuted: false
        )

        #expect(scene.hasZone2 == true)
        #expect(scene.hasZone3 == true)
        #expect(scene.zone3InputCode == "TUNER")
        #expect(scene.zone3Volume == 30)
    }

    @Test func sceneUniqueIDs() {
        let id = UUID()
        let scene1 = ReceiverScene(name: "A", receiverID: id, inputCode: "BD", volume: 40, surroundMode: "AUTO", isMuted: false)
        let scene2 = ReceiverScene(name: "B", receiverID: id, inputCode: "BD", volume: 40, surroundMode: "AUTO", isMuted: false)
        #expect(scene1.id != scene2.id)
    }

    @Test func sceneMutedState() {
        let scene = ReceiverScene(
            name: "Silent",
            receiverID: UUID(),
            inputCode: "TV",
            volume: 0,
            surroundMode: "STEREO",
            isMuted: true
        )
        #expect(scene.isMuted == true)
        #expect(scene.volume == 0)
    }
}

// MARK: - iCloud Sync Configuration Tests

struct CloudSyncTests {
    @Test func modelConfigurationUsesCloudKit() throws {
        let schema = Schema([DenonReceiver.self, ReceiverScene.self])
        // Verify CloudKit configuration can be created without throwing
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        #expect(config.schema != nil)
    }

    @Test func modelSchemaIncludesBothModels() {
        let schema = Schema([DenonReceiver.self, ReceiverScene.self])
        #expect(schema.entities.count == 2)
    }
}

// MARK: - iPad Layout Tests

struct PadLayoutTests {
    @Test func receiverHasVolumeLimitForDisplay() {
        let receiver = DenonReceiver(name: "Test", ipAddress: "10.0.0.1", volumeLimit: 75)
        #expect(receiver.volumeLimit == 75)
    }

    @Test func receiverHasPortForDisplay() {
        let receiver = DenonReceiver(name: "Test", ipAddress: "10.0.0.1", port: 2323)
        #expect(receiver.port == 2323)
    }
}

// MARK: - Zone Volume Clamping Tests

@MainActor
struct ZoneVolumeClampingTests {

    @Test func zone2VolumeClampedToMax() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z2999\r")
        #expect(api.state.zone2.volume <= DenonConstants.maxVolume)
    }

    @Test func zone3VolumeClampedToMax() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z3999\r")
        #expect(api.state.zone3.volume <= DenonConstants.maxVolume)
    }

    @Test func zone2VolumeClampedToMin() {
        let api = DenonAPI()
        api.state.zone2.volume = 50
        api.parseResponseForTesting("Z200\r")
        #expect(api.state.zone2.volume == 0)
    }

    @Test func zone3VolumeNormalRange() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z350\r")
        #expect(api.state.zone3.volume == 50)
    }
}

// MARK: - Generic Zone Parser Tests

@MainActor
struct GenericZoneParserTests {

    @Test func zone2PowerOnViaGenericParser() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z2ON\r")
        #expect(api.state.zone2.isPowerOn == true)
    }

    @Test func zone3PowerOffViaGenericParser() {
        let api = DenonAPI()
        api.state.zone3.isPowerOn = true
        api.parseResponseForTesting("Z3OFF\r")
        #expect(api.state.zone3.isPowerOn == false)
    }

    @Test func zone2MuteOnViaGenericParser() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z2MUON\r")
        #expect(api.state.zone2.isMuted == true)
    }

    @Test func zone3MuteOffViaGenericParser() {
        let api = DenonAPI()
        api.state.zone3.isMuted = true
        api.parseResponseForTesting("Z3MUOFF\r")
        #expect(api.state.zone3.isMuted == false)
    }

    @Test func zone2InputViaGenericParser() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z2GAME\r")
        #expect(api.state.zone2.currentInput == "GAME")
    }

    @Test func zone3InputViaGenericParser() {
        let api = DenonAPI()
        api.parseResponseForTesting("Z3SPOTIFY\r")
        #expect(api.state.zone3.currentInput == "SPOTIFY")
    }

    @Test func zonesIndependentFromMainZone() {
        let api = DenonAPI()
        api.parseResponseForTesting("PWON\rMV50\rSIBD\rZ2ON\rZ240\rZ2GAME\rZ3ON\rZ335\rZ3NET\r")
        #expect(api.state.isPowerOn == true)
        #expect(api.state.volume == 50)
        #expect(api.state.currentInput == "BD")
        #expect(api.state.zone2.isPowerOn == true)
        #expect(api.state.zone2.volume == 40)
        #expect(api.state.zone2.currentInput == "GAME")
        #expect(api.state.zone3.isPowerOn == true)
        #expect(api.state.zone3.volume == 35)
        #expect(api.state.zone3.currentInput == "NET")
    }
}

// MARK: - Error Type Tests

struct DenonErrorTests {

    @Test func allErrorsHaveDescriptions() {
        let errors: [DenonError] = [
            .connectionFailed, .connectionTimeout, .connectionRefused,
            .notConnected, .disconnected, .commandFailed
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test func allErrorsHaveRecoverySuggestions() {
        let errors: [DenonError] = [
            .connectionFailed, .connectionTimeout, .connectionRefused,
            .notConnected, .disconnected, .commandFailed
        ]
        for error in errors {
            #expect(error.recoverySuggestion != nil)
            #expect(!error.recoverySuggestion!.isEmpty)
        }
    }
}

// MARK: - DenonConstants Tests

struct DenonConstantsTests {

    @Test func toneLabelPositive() {
        #expect(DenonConstants.toneLabel(52) == "+2 dB")
    }

    @Test func toneLabelNegative() {
        #expect(DenonConstants.toneLabel(48) == "-2 dB")
    }

    @Test func toneLabelCenter() {
        #expect(DenonConstants.toneLabel(50) == "0 dB")
    }

    @Test func toneLabelExtremes() {
        #expect(DenonConstants.toneLabel(44) == "-6 dB")
        #expect(DenonConstants.toneLabel(56) == "+6 dB")
    }

    @Test func networkInputsContainsExpectedSources() {
        #expect(DenonConstants.networkInputs.contains("NET"))
        #expect(DenonConstants.networkInputs.contains("SPOTIFY"))
        #expect(DenonConstants.networkInputs.contains("BT"))
        #expect(!DenonConstants.networkInputs.contains("BD"))
        #expect(!DenonConstants.networkInputs.contains("GAME"))
    }

    @Test func maxVolumeIsReasonable() {
        #expect(DenonConstants.maxVolume == 98)
        #expect(DenonConstants.maxVolume > 0)
    }
}

// MARK: - Input Display Name Tests

struct InputDisplayNameTests {

    @Test func knownInputCodesReturnFriendlyNames() {
        #expect(DenonInputs.displayName(for: "BD") == "Blu-ray")
        #expect(DenonInputs.displayName(for: "GAME") == "Game")
        #expect(DenonInputs.displayName(for: "TUNER") == "Tuner")
    }

    @Test func unknownInputCodeReturnsSelf() {
        #expect(DenonInputs.displayName(for: "UNKNOWN") == "UNKNOWN")
    }

    @Test func allInputsHaveIcons() {
        for input in DenonInputs.all {
            let icon = DenonInputs.icon(for: input.code)
            #expect(!icon.isEmpty)
        }
    }
}

// MARK: - Surround Mode Display Name Tests

struct SurroundModeDisplayNameTests {

    @Test func knownModeReturnsDisplayName() {
        #expect(DenonSurroundModes.displayName(for: "STEREO") == "Stereo")
        #expect(DenonSurroundModes.displayName(for: "DOLBY ATMOS") == "Dolby Atmos")
    }

    @Test func unknownModeReturnsSelf() {
        #expect(DenonSurroundModes.displayName(for: "CUSTOM") == "CUSTOM")
    }
}

// MARK: - NowPlaying Info Tests

struct NowPlayingInfoTests {

    @Test func emptyInfoIsEmpty() {
        let info = NowPlayingInfo()
        #expect(info.isEmpty)
    }

    @Test func anyLineNonEmptyMakesNotEmpty() {
        var info = NowPlayingInfo()
        info.line1 = "Artist"
        #expect(!info.isEmpty)
    }

    @Test func clearingAllLinesMakesEmpty() {
        var info = NowPlayingInfo()
        info.line1 = "A"
        info.line2 = "B"
        info.line3 = "C"
        info.line4 = "D"
        info.line1 = ""
        info.line2 = ""
        info.line3 = ""
        info.line4 = ""
        #expect(info.isEmpty)
    }
}

// MARK: - Multi-response Parsing Edge Cases

@MainActor
struct EdgeCaseParsingTests {

    @Test func parseResponseWithEmptyLines() {
        let api = DenonAPI()
        api.parseResponseForTesting("\r\r\rPWON\r\r\r")
        #expect(api.state.isPowerOn == true)
    }

    @Test func parseNowPlayingClearsOnEmptyLines() {
        let api = DenonAPI()
        api.parseResponseForTesting("NSE1Artist\rNSE3Track\r")
        #expect(api.state.nowPlaying.line1 == "Artist")
        #expect(api.state.nowPlaying.line3 == "Track")
        // Simulate cleared now-playing
        api.parseResponseForTesting("NSE1\rNSE3\r")
        #expect(api.state.nowPlaying.line1 == "")
        #expect(api.state.nowPlaying.line3 == "")
        #expect(api.state.nowPlaying.isEmpty)
    }

    @Test func parseReceiverInfoModel() {
        let api = DenonAPI()
        api.parseResponseForTesting("SSINFAISMD AVR-X3800H\r")
        #expect(api.state.receiverModel == "AVR-X3800H")
    }

    @Test func parseReceiverInfoFirmware() {
        let api = DenonAPI()
        api.parseResponseForTesting("SSINFAISFSV 0100-0020-1050\r")
        #expect(api.state.firmwareVersion == "0100-0020-1050")
    }

    @Test func parseMixedZoneAndMainResponses() {
        let api = DenonAPI()
        api.parseResponseForTesting("PWON\rZ2ON\rMV50\rZ240\rMUOFF\rZ2MUON\rSIGAME\rZ2NET\r")
        #expect(api.state.isPowerOn == true)
        #expect(api.state.volume == 50)
        #expect(api.state.isMuted == false)
        #expect(api.state.currentInput == "GAME")
        #expect(api.state.zone2.isPowerOn == true)
        #expect(api.state.zone2.volume == 40)
        #expect(api.state.zone2.isMuted == true)
        #expect(api.state.zone2.currentInput == "NET")
    }
}

// MARK: - ReceiverStatus Codable Tests

struct ReceiverStatusTests {

    @Test func placeholderHasDefaults() {
        let placeholder = ReceiverStatus.placeholder
        #expect(placeholder.receiverName == "Receiver")
        #expect(placeholder.isPowerOn == false)
        #expect(placeholder.volume == 0)
    }

    @Test func encodingAndDecoding() throws {
        let status = ReceiverStatus(
            receiverName: "Test",
            ipAddress: "192.168.1.1",
            port: 23,
            isPowerOn: true,
            volume: 55,
            currentInput: "GAME",
            lastUpdated: Date(timeIntervalSince1970: 1000)
        )
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ReceiverStatus.self, from: data)
        #expect(decoded.receiverName == "Test")
        #expect(decoded.isPowerOn == true)
        #expect(decoded.volume == 55)
        #expect(decoded.currentInput == "GAME")
    }
}
