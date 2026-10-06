/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if os(iOS)

import XCTest
import TestUtilities
import KubesenseInternal
@_spi(objc)
@testable import KubesenseSessionReplay

class KubesenseSessionReplayOverrideTests: XCTestCase {
    // MARK: Privacy Overrides Interoperability
    func testTextAndInputPrivacyLevelsOverrideInterop() {
        XCTAssertEqual(objc_TextAndInputPrivacyLevelOverride.maskAll._swift, .maskAll)
        XCTAssertEqual(objc_TextAndInputPrivacyLevelOverride.maskAllInputs._swift, .maskAllInputs)
        XCTAssertEqual(objc_TextAndInputPrivacyLevelOverride.maskSensitiveInputs._swift, .maskSensitiveInputs)
        XCTAssertNil(objc_TextAndInputPrivacyLevelOverride.none._swift)

        XCTAssertEqual(objc_TextAndInputPrivacyLevelOverride(.maskAll), .maskAll)
        XCTAssertEqual(objc_TextAndInputPrivacyLevelOverride(.maskAllInputs), .maskAllInputs)
        XCTAssertEqual(objc_TextAndInputPrivacyLevelOverride(.maskSensitiveInputs), .maskSensitiveInputs)
        XCTAssertEqual(objc_TextAndInputPrivacyLevelOverride(nil), .none)
    }

    func testImagePrivacyLevelsOverrideInterop() {
        XCTAssertEqual(objc_ImagePrivacyLevelOverride.maskAll._swift, .maskAll)
        XCTAssertEqual(objc_ImagePrivacyLevelOverride.maskNonBundledOnly._swift, .maskNonBundledOnly)
        XCTAssertEqual(objc_ImagePrivacyLevelOverride.maskNone._swift, .maskNone)
        XCTAssertNil(objc_ImagePrivacyLevelOverride.none._swift)

        XCTAssertEqual(objc_ImagePrivacyLevelOverride(.maskAll), .maskAll)
        XCTAssertEqual(objc_ImagePrivacyLevelOverride(.maskNonBundledOnly), .maskNonBundledOnly)
        XCTAssertEqual(objc_ImagePrivacyLevelOverride(.maskNone), .maskNone)
        XCTAssertEqual(objc_ImagePrivacyLevelOverride(nil), .none)
    }

    func testTouchPrivacyLevelsOverrideInterop() {
        XCTAssertEqual(objc_TouchPrivacyLevelOverride.show._swift, .show)
        XCTAssertEqual(objc_TouchPrivacyLevelOverride.hide._swift, .hide)
        XCTAssertNil(objc_TouchPrivacyLevelOverride.none._swift)

        XCTAssertEqual(objc_TouchPrivacyLevelOverride(.show), .show)
        XCTAssertEqual(objc_TouchPrivacyLevelOverride(.hide), .hide)
        XCTAssertEqual(objc_TouchPrivacyLevelOverride(nil), .none)
    }

    func testHidePrivacyLevelsOverrideInterop() {
        // Testing Swift -> Objective-C interaction
        let view = UIView()
        let objcOverrides = view.kubesenseSessionReplayPrivacyOverrides

        // Set via Swift
        view.kubesense.sessionReplayPrivacyOverrides.hide = true
        XCTAssertEqual(objcOverrides.hide, NSNumber(value: true))

        view.kubesense.sessionReplayPrivacyOverrides.hide = false
        XCTAssertEqual(objcOverrides.hide, NSNumber(value: false))

        view.kubesense.sessionReplayPrivacyOverrides.hide = nil
        XCTAssertNil(objcOverrides.hide)

        // Set via Objective-C
        objcOverrides.hide = NSNumber(value: true)
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.hide, true)

        objcOverrides.hide = NSNumber(value: false)
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.hide, false)

        objcOverrides.hide = nil
        XCTAssertNil(view.kubesense.sessionReplayPrivacyOverrides.hide)
    }

    // MARK: Setting Privacy Overrides
    func testSettingAndClearingObjectOverridesInObjc() {
        // Given
        let textAndInputPrivacy: objc_TextAndInputPrivacyLevelOverride = .mockRandom()
        let imagePrivacy: objc_ImagePrivacyLevelOverride = .mockRandom()
        let touchPrivacy: objc_TouchPrivacyLevelOverride = .mockRandom()
        let hidePrivacy = NSNumber.mockRandomBoolean()

        // When
        let overrides = objc_SessionReplayPrivacyOverrides(view: UIView())
        overrides.textAndInputPrivacy = textAndInputPrivacy
        overrides.imagePrivacy = imagePrivacy
        overrides.touchPrivacy = touchPrivacy
        overrides.hide = hidePrivacy

        // Then
        XCTAssertEqual(overrides.textAndInputPrivacy, textAndInputPrivacy)
        XCTAssertEqual(overrides.imagePrivacy, imagePrivacy)
        XCTAssertEqual(overrides.touchPrivacy, touchPrivacy)
        XCTAssertEqual(overrides.hide, hidePrivacy)

        // When
        overrides.textAndInputPrivacy = .none
        overrides.imagePrivacy = .none
        overrides.touchPrivacy = .none
        overrides.hide = false

        // Then
        XCTAssertEqual(overrides.textAndInputPrivacy, .none)
        XCTAssertEqual(overrides.imagePrivacy, .none)
        XCTAssertEqual(overrides.touchPrivacy, .none)
        XCTAssertEqual(overrides.hide, false)
    }

    func testSettingAndClearingViewOverridesInObjc() {
        // Given
        let view = UIView()
        let textAndInputPrivacy: objc_TextAndInputPrivacyLevelOverride = .mockRandom()
        let imagePrivacy: objc_ImagePrivacyLevelOverride = .mockRandom()
        let touchPrivacy: objc_TouchPrivacyLevelOverride = .mockRandom()
        let hidePrivacy = NSNumber.mockRandomBoolean()

        // When
        view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy = textAndInputPrivacy
        view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy = imagePrivacy
        view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy = touchPrivacy
        view.kubesenseSessionReplayPrivacyOverrides.hide = hidePrivacy

        // Then
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy, textAndInputPrivacy)
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy, imagePrivacy)
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy, touchPrivacy)
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.hide, hidePrivacy)

        // When
        view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy = .none
        view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy = .none
        view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy = .none
        view.kubesenseSessionReplayPrivacyOverrides.hide = nil

        // Then
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy, .none)
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy, .none)
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy, .none)
        XCTAssertNil(view.kubesenseSessionReplayPrivacyOverrides.hide)
    }

    func testSwiftChangesReflectInObjC() {
        // Given
        let view = UIView()
        let textAndInputPrivacy: objc_TextAndInputPrivacyLevelOverride = .mockRandom()
        let imagePrivacy: objc_ImagePrivacyLevelOverride = .mockRandom()
        let touchPrivacy: objc_TouchPrivacyLevelOverride = .mockRandom()
        let hidePrivacy = NSNumber.mockRandomBoolean()

        // When (set in Swift)
        view.kubesense.sessionReplayPrivacyOverrides.textAndInputPrivacy = textAndInputPrivacy._swift
        view.kubesense.sessionReplayPrivacyOverrides.imagePrivacy = imagePrivacy._swift
        view.kubesense.sessionReplayPrivacyOverrides.touchPrivacy = touchPrivacy._swift
        view.kubesense.sessionReplayPrivacyOverrides.hide = hidePrivacy?.boolValue

        // Then (check in ObjC)
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy, textAndInputPrivacy)
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy, imagePrivacy)
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy, touchPrivacy)
        XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.hide, hidePrivacy)
    }

    func testObjCChangesReflectInSwift() {
        // Given
        let view = UIView()
        let textAndInputPrivacy: objc_TextAndInputPrivacyLevelOverride = .mockRandom()
        let imagePrivacy: objc_ImagePrivacyLevelOverride = .mockRandom()
        let touchPrivacy: objc_TouchPrivacyLevelOverride = .mockRandom()
        let hidePrivacy = NSNumber.mockRandomBoolean()

        // When (set in ObjC)
        view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy = textAndInputPrivacy
        view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy = imagePrivacy
        view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy = touchPrivacy
        view.kubesenseSessionReplayPrivacyOverrides.hide = hidePrivacy

        // Then (check in Swift)
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.textAndInputPrivacy, textAndInputPrivacy._swift)
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.imagePrivacy, imagePrivacy._swift)
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.touchPrivacy, touchPrivacy._swift)
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.hide, hidePrivacy?.boolValue)
    }

    func testReleasingOverridesWhenViewIsDeallocated() {
        weak var view: UIView?

        autoreleasepool {
            let tempView = UIView()
            view = tempView
            tempView.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy = .mockRandom()
            tempView.kubesenseSessionReplayPrivacyOverrides.imagePrivacy = .mockRandom()
            tempView.kubesenseSessionReplayPrivacyOverrides.touchPrivacy = .mockRandom()
            tempView.kubesenseSessionReplayPrivacyOverrides.hide = NSNumber.mockRandomBoolean()
        }

        XCTAssertNil(view?.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy)
        XCTAssertNil(view?.kubesenseSessionReplayPrivacyOverrides.imagePrivacy)
        XCTAssertNil(view?.kubesenseSessionReplayPrivacyOverrides.touchPrivacy)
        XCTAssertNil(view?.kubesenseSessionReplayPrivacyOverrides.hide)
    }
}
#endif
