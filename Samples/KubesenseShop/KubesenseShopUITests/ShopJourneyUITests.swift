/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import XCTest

/// Walks the main shopping journey so one run produces views, actions, resources, a user
/// context, an order and diagnostics signals. Needs the sample API to be reachable.
final class ShopJourneyUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
    }

    func testShoppingJourney() {
        let addButton = app.buttons["Add"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 20))
        snapshot("1-shop")

        addButton.tap()
        XCTAssertTrue(app.staticTexts["Your cart"].waitForExistence(timeout: 5))
        snapshot("2-cart")

        app.tabBars.buttons["Account"].tap()
        if app.buttons["Sign out"].exists { app.buttons["Sign out"].tap() }
        app.buttons["Sign in"].tap()
        XCTAssertTrue(app.buttons["Sign out"].waitForExistence(timeout: 15))
        app.buttons["Get current session"].tap()
        snapshot("3-account")

        app.tabBars.buttons["Cart"].tap()
        app.buttons["Continue to checkout"].tap()
        let placeOrder = app.buttons["Place order"]
        XCTAssertTrue(placeOrder.waitForExistence(timeout: 5))
        snapshot("4-checkout")
        placeOrder.tap()
        if !app.staticTexts["Order history"].waitForExistence(timeout: 15) {
            snapshot("5-order-failed")
            XCTFail("Order history did not open after placing the order")
            return
        }
        snapshot("5-orders")

        app.tabBars.buttons["Diagnostics"].tap()
        for title in ["Manual action", "Custom timing", "Handled error", "Log burst", "Manual trace"] {
            let row = app.cells.containing(.staticText, identifier: title).firstMatch
            for _ in 0..<6 where !(row.exists && row.isHittable) {
                app.swipeUp()
            }
            XCTAssertTrue(row.waitForExistence(timeout: 5), "\(title) row not found")
            row.buttons["Run"].tap()
        }
        snapshot("6-diagnostics")

        let openLegacy = app.buttons["Open UIKit views & WebView tests"]
        for _ in 0..<6 where !(openLegacy.exists && openLegacy.isHittable) {
            app.swipeDown()
        }
        openLegacy.tap()
        XCTAssertTrue(app.buttons["Send legacy-view action"].waitForExistence(timeout: 5))
        app.buttons["Send legacy-view action"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Web checkout"].waitForExistence(timeout: 10))
        snapshot("7-uikit-webview")

        // Background the app so the SDK flushes its batches before the run ends.
        XCUIDevice.shared.press(.home)
        sleep(15)
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
