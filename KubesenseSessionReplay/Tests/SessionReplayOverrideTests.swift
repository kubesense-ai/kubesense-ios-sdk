/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#if os(iOS)
import XCTest
import UIKit
@_spi(Internal)
@testable import TestUtilities
@_spi(Internal)
@testable import KubesenseSessionReplay

class SessionReplayPrivacyOverridesTests: XCTestCase {
    // MARK: Setting Overrides
    func testWhenNoOverrideIsSet_itDefaultsToNil() {
        // Given
        let view = UIView()

        // Then
        XCTAssertNil(view.kubesense.sessionReplayPrivacyOverrides.textAndInputPrivacy)
        XCTAssertNil(view.kubesense.sessionReplayPrivacyOverrides.imagePrivacy)
        XCTAssertNil(view.kubesense.sessionReplayPrivacyOverrides.touchPrivacy)
        XCTAssertNil(view.kubesense.sessionReplayPrivacyOverrides.hide)

        XCTAssertNotNil(view.kubesense._privacyOverrides)
        XCTAssertNil(view.kubesense._privacyOverrides?.textAndInputPrivacy)
        XCTAssertNil(view.kubesense._privacyOverrides?.imagePrivacy)
        XCTAssertNil(view.kubesense._privacyOverrides?.touchPrivacy)
        XCTAssertNil(view.kubesense._privacyOverrides?.hide)
    }

    func testWithOverrides() {
        // Given
        let view = UIView()

        // When
        view.kubesense.sessionReplayPrivacyOverrides.textAndInputPrivacy = .maskAllInputs
        view.kubesense.sessionReplayPrivacyOverrides.imagePrivacy = .maskAll
        view.kubesense.sessionReplayPrivacyOverrides.touchPrivacy = .hide
        view.kubesense.sessionReplayPrivacyOverrides.hide = true

        // Then
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.textAndInputPrivacy, .maskAllInputs)
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.imagePrivacy, .maskAll)
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.touchPrivacy, .hide)
        XCTAssertEqual(view.kubesense.sessionReplayPrivacyOverrides.hide, true)

        XCTAssertNotNil(view.kubesense._privacyOverrides)
        XCTAssertEqual(view.kubesense._privacyOverrides?.textAndInputPrivacy, .maskAllInputs)
        XCTAssertEqual(view.kubesense._privacyOverrides?.imagePrivacy, .maskAll)
        XCTAssertEqual(view.kubesense._privacyOverrides?.touchPrivacy, .hide)
        XCTAssertEqual(view.kubesense._privacyOverrides?.hide, true)
    }

    func testRemovingOverrides() {
        // Given
        let view = UIView()
        view.kubesense.sessionReplayPrivacyOverrides.textAndInputPrivacy = .maskAllInputs
        view.kubesense.sessionReplayPrivacyOverrides.imagePrivacy = .maskAll
        view.kubesense.sessionReplayPrivacyOverrides.touchPrivacy = .hide
        view.kubesense.sessionReplayPrivacyOverrides.hide = true

        // When
        view.kubesense.sessionReplayPrivacyOverrides.textAndInputPrivacy = nil
        view.kubesense.sessionReplayPrivacyOverrides.imagePrivacy = nil
        view.kubesense.sessionReplayPrivacyOverrides.touchPrivacy = nil
        view.kubesense.sessionReplayPrivacyOverrides.hide = nil

        // Then
        XCTAssertNil(view.kubesense.sessionReplayPrivacyOverrides.textAndInputPrivacy)
        XCTAssertNil(view.kubesense.sessionReplayPrivacyOverrides.imagePrivacy)
        XCTAssertNil(view.kubesense.sessionReplayPrivacyOverrides.touchPrivacy)
        XCTAssertNil(view.kubesense.sessionReplayPrivacyOverrides.hide)

        XCTAssertNotNil(view.kubesense._privacyOverrides)
        XCTAssertNil(view.kubesense._privacyOverrides?.textAndInputPrivacy)
        XCTAssertNil(view.kubesense._privacyOverrides?.imagePrivacy)
        XCTAssertNil(view.kubesense._privacyOverrides?.touchPrivacy)
        XCTAssertNil(view.kubesense._privacyOverrides?.hide)
    }

    // MARK: Privacy Overrides taking precedence over global settings
    func testTextOverrideTakesPrecedenceOverGlobalTextPrivacy() {
        // Given
        let textAndInputOverride: TextAndInputPrivacyLevel = .mockRandom()
        let viewAttributes: ViewAttributes = .mockWith(overrides: .mockWith(textAndInputPrivacy: textAndInputOverride))
        let globalTextAndInputPrivacy: TextAndInputPrivacyLevel = .mockRandom()
        let context = ViewTreeRecordingContext.mockWith(recorder: .mockWith(textAndInputPrivacy: globalTextAndInputPrivacy))

        // When
        let resolvedTextPrivacy = viewAttributes.resolveTextAndInputPrivacyLevel(in: context)

        // Then
        XCTAssertEqual(resolvedTextPrivacy, textAndInputOverride)
    }

    func testTextGlobalPrivacyIsUsedWhenNoTextOverrideIsSet() {
        // Given
        let viewAttributes: ViewAttributes = .mockAny()
        let globalTextAndInputPrivacy: TextAndInputPrivacyLevel = .mockRandom()
        let context = ViewTreeRecordingContext.mockWith(recorder: .mockWith(textAndInputPrivacy: globalTextAndInputPrivacy))

        // When
        let resolvedPrivacy = viewAttributes.resolveTextAndInputPrivacyLevel(in: context)

        // Then
        XCTAssertEqual(resolvedPrivacy, globalTextAndInputPrivacy)
    }

    func testImageOverrideTakesPrecedenceOverGlobalImagePrivacy() {
        // Given
        let imageOverride: ImagePrivacyLevel = .mockRandom()
        let viewAttributes: ViewAttributes = .mockWith(overrides: .mockWith(imagePrivacy: imageOverride))
        let globalImagePrivacy: ImagePrivacyLevel = .mockRandom()
        let context = ViewTreeRecordingContext.mockWith(recorder: .mockWith(imagePrivacy: globalImagePrivacy))

        // When
        let resolvedImagePrivacy = viewAttributes.resolveImagePrivacyLevel(in: context)

        // Then
        XCTAssertEqual(resolvedImagePrivacy, imageOverride)
    }

    func testImageGlobalPrivacyIsUsedWhenNoImageOverrideIsSet() {
        // Given
        let viewAttributes: ViewAttributes = .mockAny()
        let globalImagePrivacy: ImagePrivacyLevel = .mockRandom()
        let context = ViewTreeRecordingContext.mockWith(recorder: .mockWith(imagePrivacy: globalImagePrivacy))

        // When
        let resolvedImagePrivacy = viewAttributes.resolveImagePrivacyLevel(in: context)

        // Then
        XCTAssertEqual(resolvedImagePrivacy, globalImagePrivacy)
    }

    // MARK: Privacy Overrides Merge
    func testMergeParentAndChildOverrides() throws {
        // Given
        let overrides: PrivacyOverrides = .mockRandom()

        let childOverrides: PrivacyOverrides = .mockAny()
        childOverrides.textAndInputPrivacy = overrides.textAndInputPrivacy
        // We set the `hide` override on the child because in the merge process,
        // the child's override takes precedence. If the parent's `hide` is `false`,
        // the final merged value will end up as `nil`, which makes the test fail.
        childOverrides.hide = overrides.hide

        let parentOverrides: PrivacyOverrides = .mockAny()
        parentOverrides.imagePrivacy = overrides.imagePrivacy
        parentOverrides.touchPrivacy = overrides.touchPrivacy

        // When
        let merged = try XCTUnwrap(SessionReplayPrivacyOverrides.merge(childOverrides, with: parentOverrides))

        // Then
        XCTAssertEqual(merged.textAndInputPrivacy, overrides.textAndInputPrivacy)
        XCTAssertEqual(merged.imagePrivacy, overrides.imagePrivacy)
        XCTAssertEqual(merged.touchPrivacy, overrides.touchPrivacy)
        XCTAssertEqual(merged.touchPrivacy, overrides.touchPrivacy)
    }

    func testMergeWithNilParentOverrides() throws {
        // Given
        let childOverrides: PrivacyOverrides = .mockRandom()
        let parentOverrides: PrivacyOverrides = .mockAny()

        // When
        let merged = try XCTUnwrap(SessionReplayPrivacyOverrides.merge(childOverrides, with: parentOverrides))

        // Then
        XCTAssertEqual(merged.textAndInputPrivacy, childOverrides.textAndInputPrivacy)
        XCTAssertEqual(merged.imagePrivacy, childOverrides.imagePrivacy)
        XCTAssertEqual(merged.touchPrivacy, childOverrides.touchPrivacy)
        XCTAssertEqual(merged.hide, childOverrides.hide)
    }

    func testMergeWithNilChildOverrides() throws {
        // Given
        let childOverrides: PrivacyOverrides = .mockAny()
        let parentOverrides: PrivacyOverrides = .mockRandom()
        /// We explicitly set `hide` to `true` in the parent override because the child’s `hide` is `nil`.
        /// In the merge logic, `true` takes precedence, and `false` behaves the same as `nil`, meaning no override.
        parentOverrides.hide = true

        // When
        let merged = try XCTUnwrap(SessionReplayPrivacyOverrides.merge(childOverrides, with: parentOverrides))
        // Then
        XCTAssertEqual(merged.textAndInputPrivacy, parentOverrides.textAndInputPrivacy)
        XCTAssertEqual(merged.imagePrivacy, parentOverrides.imagePrivacy)
        XCTAssertEqual(merged.touchPrivacy, parentOverrides.touchPrivacy)
        XCTAssertEqual(merged.hide, parentOverrides.hide)
    }

    func testMergeWhenChildHideOverrideIsNotNilAndParentHideOverrideIsTrue() throws {
        // Given
        let childOverrides: PrivacyOverrides = .mockRandom()
        childOverrides.hide = false
        let parentOverrides: PrivacyOverrides = .mockRandom()
        parentOverrides.hide = true

        // When
        let merged = try XCTUnwrap(SessionReplayPrivacyOverrides.merge(childOverrides, with: parentOverrides))

        // Then
        XCTAssertEqual(merged.textAndInputPrivacy, childOverrides.textAndInputPrivacy)
        XCTAssertEqual(merged.imagePrivacy, childOverrides.imagePrivacy)
        XCTAssertEqual(merged.touchPrivacy, childOverrides.touchPrivacy)
        XCTAssertEqual(merged.hide, true)
    }

    func testMergeOptimizationWhenNeitherHasOverrides() throws {
        // Given
        let childOverrides: PrivacyOverrides = .mockAny()
        let parentOverrides: PrivacyOverrides = .mockAny()

        // When
        let merged = try XCTUnwrap(SessionReplayPrivacyOverrides.merge(childOverrides, with: parentOverrides))

        // Then
        XCTAssertNil(merged.textAndInputPrivacy)
        XCTAssertNil(merged.imagePrivacy)
        XCTAssertNil(merged.touchPrivacy)
        XCTAssertNil(merged.hide)
    }

    func testViewDeallocatesCorrectly() throws {
        // Weak reference acting as an observer to the target object view
        weak var weakView: UIView?
        let randomValues: PrivacyOverrides = .mockRandom()

        autoreleasepool {
            // Strong reference to the view
            let view = UIView()
            // Weak reference to the view
            weakView = view
            view.kubesense.sessionReplayPrivacyOverrides.textAndInputPrivacy = randomValues.textAndInputPrivacy
            view.kubesense.sessionReplayPrivacyOverrides.imagePrivacy = randomValues.imagePrivacy
            view.kubesense.sessionReplayPrivacyOverrides.touchPrivacy = randomValues.touchPrivacy
            view.kubesense.sessionReplayPrivacyOverrides.hide = randomValues.hide

            // Captures overrides values without retaining the view
            let attributes = ViewAttributes(
                view: view,
                frame: view.frame,
                clip: view.frame,
                overrides: view.kubesense.sessionReplayPrivacyOverrides
            )

            // Check attributes are captured and not optimized away
            XCTAssertEqual(attributes.textAndInputPrivacy, randomValues.textAndInputPrivacy)
            XCTAssertEqual(attributes.imagePrivacy, randomValues.imagePrivacy)
            XCTAssertEqual(attributes.touchPrivacy, randomValues.touchPrivacy)
            XCTAssertEqual(attributes.hide, randomValues.hide)
            // View still exists
            XCTAssertNotNil(weakView)
        }

        // View has been deallocxated
        XCTAssertNil(weakView, "View should be deallocated")
    }
}

#endif
