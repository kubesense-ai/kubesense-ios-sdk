/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */

import XCTest

/// Measures what the SDK costs the Kubesense Shop: the same launch and the same catalog scroll, with
/// the SDK off, with RUM only, with RUM and Session Replay, and with every feature the sample enables.
/// `Benchmarks/report.py` turns the results into a table of medians and overhead against `off`.
///
/// The app runs on its offline catalog, so the shop's own API calls do not add noise, and with
/// `KUBESENSE_ENV=benchmark`, so these sessions can be filtered out on the dashboard. SDK uploads
/// stay on: they are part of the cost being measured.
final class SDKOverheadBenchmarks: XCTestCase {
    private enum Profile: String {
        case off, rum, replay, full
    }

    private let iterations = 5

    override func setUp() {
        continueAfterFailure = false
    }

    func testLaunch_off() { measureLaunch(.off) }
    func testLaunch_rum() { measureLaunch(.rum) }
    func testLaunch_replay() { measureLaunch(.replay) }
    func testLaunch_full() { measureLaunch(.full) }

    func testScroll_off() { measureScroll(.off) }
    func testScroll_rum() { measureScroll(.rum) }
    func testScroll_replay() { measureScroll(.replay) }
    func testScroll_full() { measureScroll(.full) }

    private func app(_ profile: Profile) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "KUBESENSE_SDK_PROFILE": profile.rawValue,
            "KUBESENSE_SDK_VERBOSE": "0",
            "KUBESENSE_ENV": "benchmark",
            "SAMPLE_API_BASE_URL": "",
        ]
        return app
    }

    private var options: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = iterations
        return options
    }

    /// Cold launch until the app is responsive, relaunched for every iteration.
    private func measureLaunch(_ profile: Profile) {
        let app = app(profile)
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
        }
        app.terminate()
    }

    /// Flings down the catalog and back to the top, so every iteration starts from the same place.
    private func measureScroll(_ profile: Profile) {
        let app = app(profile)
        app.launch()
        let catalog = app.scrollViews.firstMatch
        XCTAssertTrue(app.buttons["Add"].firstMatch.waitForExistence(timeout: 20))

        let metrics: [XCTMetric] = [
            XCTOSSignpostMetric.scrollingAndDecelerationMetric,
            XCTCPUMetric(application: app),
            XCTMemoryMetric(application: app),
            XCTClockMetric(),
        ]
        measure(metrics: metrics, options: options) {
            for _ in 0..<3 { catalog.swipeUp(velocity: .fast) }
            for _ in 0..<3 { catalog.swipeDown(velocity: .fast) }
        }
        app.terminate()
    }
}
