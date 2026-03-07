//
//  remoteUITests.swift
//  remoteUITests
//
//  Created by Matt on 3/7/26.
//

import XCTest

final class remoteUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch & Navigation

    @MainActor
    func testAppLaunchShowsReceiverList() throws {
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddReceiverButtonExists() throws {
        let addButton = app.buttons["add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
    }

    // MARK: - Add Receiver Flow

    @MainActor
    func testAddReceiverSheetPresents() throws {
        let addButton = app.buttons["add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddReceiverSheetCanBeDismissed() throws {
        let addButton = app.buttons["add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 5) {
            cancelButton.tap()
        }
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
