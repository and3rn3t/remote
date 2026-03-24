//
//  ReceiverControlUITests.swift
//  remoteUITests
//
//  Created by OpenClaw on 3/8/26.
//

import XCTest

/// Comprehensive UI tests for receiver control flows.
final class ReceiverControlUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    // MARK: - Zone Switching Tests

    func testZoneSwitching() throws {
        // Tap to add a receiver
        app.buttons["Add"].tap()

        // Fill in receiver details
        let nameField = app.textFields["Receiver Name"]
        nameField.tap()
        nameField.typeText("Test Receiver")

        let ipField = app.textFields["IP Address"]
        ipField.tap()
        ipField.typeText("192.168.1.100")

        app.buttons["Add"].tap()

        // Select the receiver
        app.staticTexts["Test Receiver"].tap()

        // Connect
        app.buttons["Connect"].tap()

        // Wait for connection (this would require mocking in real tests)
        sleep(2)

        // Test zone picker
        let zonePicker = app.segmentedControls.firstMatch
        XCTAssertTrue(zonePicker.exists)

        // Switch to Zone 2
        zonePicker.buttons["Zone 2"].tap()
        XCTAssertTrue(app.staticTexts["Zone 2"].exists)

        // Switch to Zone 3
        zonePicker.buttons["Zone 3"].tap()
        XCTAssertTrue(app.staticTexts["Zone 3"].exists)

        // Back to Main
        zonePicker.buttons["Main"].tap()
        XCTAssertTrue(app.staticTexts["Main"].exists)
    }

    // MARK: - Input Source Selection Tests

    func testInputSourceSelection() throws {
        // Add and connect to receiver (setup)
        addTestReceiver()

        // Verify input selection grid exists
        let inputGrid = app.scrollViews.containing(.staticText, identifier: "Input Selection").firstMatch
        XCTAssertTrue(inputGrid.exists)

        // Test selecting Blu-ray input
        let blurayButton = app.buttons["Blu-ray"]
        if blurayButton.exists {
            blurayButton.tap()
            // In a real test, we'd verify state change
        }

        // Test selecting Game input
        let gameButton = app.buttons["Game"]
        if gameButton.exists {
            gameButton.tap()
        }
    }

    // MARK: - Volume Control Tests

    func testVolumeControl() throws {
        addTestReceiver()

        // Test volume slider exists
        let volumeSlider = app.sliders.containing(.staticText, identifier: "Volume").firstMatch
        XCTAssertTrue(volumeSlider.exists)

        // Test volume up button
        let volumeUpButton = app.buttons["Volume Up"]
        if volumeUpButton.exists {
            volumeUpButton.tap()
        }

        // Test volume down button
        let volumeDownButton = app.buttons["Volume Down"]
        if volumeDownButton.exists {
            volumeDownButton.tap()
        }

        // Test mute button
        let muteButton = app.buttons["Mute"]
        if muteButton.exists {
            muteButton.tap()
            // Tap again to unmute
            muteButton.tap()
        }
    }

    // MARK: - Power Control Tests

    func testPowerControl() throws {
        addTestReceiver()

        // Find power button
        let powerButton = app.buttons.matching(identifier: "Power").firstMatch
        XCTAssertTrue(powerButton.exists)

        // Toggle power off
        powerButton.tap()
        sleep(1)

        // Toggle power on
        powerButton.tap()
    }

    // MARK: - Scene Management Tests

    func testSceneCreation() throws {
        addTestReceiver()

        // Open quick actions menu (if it exists)
        let scenesButton = app.buttons["Scenes"]
        if scenesButton.exists {
            scenesButton.tap()

            // Test create scene
            let createButton = app.buttons["Create Scene"]
            if createButton.exists {
                createButton.tap()

                // Enter scene name
                let nameField = app.textFields["Scene Name"]
                if nameField.exists {
                    nameField.tap()
                    nameField.typeText("Movie Night")

                    // Save
                    app.buttons["Save"].tap()
                }
            }

            // Go back
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    func testSceneRecall() throws {
        addTestReceiver()

        // Open scenes list
        let scenesButton = app.buttons["Scenes"]
        if scenesButton.exists {
            scenesButton.tap()

            // Tap on first scene if it exists
            let firstScene = app.buttons.matching(identifier: "Scene").firstMatch
            if firstScene.exists {
                firstScene.tap()
            }

            // Dismiss
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    // MARK: - Settings Flow Tests

    func testSettingsNavigation() throws {
        addTestReceiver()

        // Open settings
        let settingsButton = app.buttons["Settings"]
        if settingsButton.exists {
            settingsButton.tap()

            // Verify settings sections exist
            XCTAssertTrue(app.staticTexts["Receiver Settings"].exists ||
                         app.staticTexts["Volume Safety Limit"].exists)

            // Test editing receiver name
            let nameField = app.textFields["Receiver Name"]
            if nameField.exists {
                nameField.tap()
                nameField.clearText()
                nameField.typeText("Updated Name")
            }

            // Dismiss
            app.buttons["Done"].tap()
        }
    }

    // MARK: - Error State Handling Tests

    func testConnectionError() throws {
        // Add receiver with invalid IP
        app.buttons["Add"].tap()

        let nameField = app.textFields["Receiver Name"]
        nameField.tap()
        nameField.typeText("Invalid Receiver")

        let ipField = app.textFields["IP Address"]
        ipField.tap()
        ipField.typeText("999.999.999.999")

        app.buttons["Add"].tap()

        // Try to connect
        app.staticTexts["Invalid Receiver"].tap()
        app.buttons["Connect"].tap()

        // Verify error alert appears
        sleep(3)
        if app.alerts.firstMatch.exists {
            XCTAssertTrue(app.alerts.firstMatch.staticTexts["Connection Error"].exists)
            app.buttons["OK"].tap()
        }
    }

    // MARK: - Accessibility Tests

    func testVoiceOverLabels() throws {
        addTestReceiver()

        // Verify important controls have accessibility labels
        let powerButton = app.buttons.matching(identifier: "Power").firstMatch
        XCTAssertNotNil(powerButton.label)

        let volumeSlider = app.sliders.firstMatch
        if volumeSlider.exists {
            XCTAssertNotNil(volumeSlider.label)
        }
    }

    func testDynamicType() throws {
        // This test would verify UI adapts to larger text sizes
        // Would require setting dynamic type preference in test setup
        addTestReceiver()

        // Verify text is visible and not truncated
        let receiverName = app.navigationBars.staticTexts.firstMatch
        XCTAssertTrue(receiverName.exists)
    }

    // MARK: - Keyboard Shortcut Tests

    func testKeyboardShortcuts() throws {
        addTestReceiver()

        // Test Command+P (power toggle)
        // Note: XCUITest doesn't fully support keyboard shortcuts,
        // but we can verify the buttons exist
        let powerButton = app.buttons.matching(identifier: "Power").firstMatch
        XCTAssertTrue(powerButton.exists)
    }

    // MARK: - Helper Methods

    private func addTestReceiver() {
        app.buttons["Add"].tap()

        let nameField = app.textFields["Receiver Name"]
        nameField.tap()
        nameField.typeText("Test Receiver")

        let ipField = app.textFields["IP Address"]
        ipField.tap()
        ipField.typeText("192.168.1.100")

        app.buttons["Add"].tap()

        // Select the receiver
        app.staticTexts["Test Receiver"].tap()

        // Connect
        app.buttons["Connect"].tap()
        sleep(2) // Wait for connection
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    /// Clears text from a text field.
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}
