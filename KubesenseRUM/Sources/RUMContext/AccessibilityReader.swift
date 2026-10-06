/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import KubesenseInternal
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

internal protocol AccessibilityReading {
    /// The current accessibility state containing all accessibility settings
    var state: AccessibilityInfo { get }
}

#if !os(watchOS)
internal final class AccessibilityReader: AccessibilityReading {
    @ReadWriteLock
    private(set) var state: AccessibilityInfo

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter) {
        self.state = AccessibilityInfo()
        self.notificationCenter = notificationCenter
        startObserving()
        updateState()
    }

    deinit {
        stopObserving()
    }

    private func updateState() {
        Task { @MainActor in
            self.state = self.currentState
        }
    }

    private func startObserving() {
        #if canImport(UIKit)
        let buttonShapesObserver = notificationCenter.addObserver(
            forName: UIAccessibility.buttonShapesEnabledStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(buttonShapesObserver)

        let crossFadeTransitionsObserver = notificationCenter.addObserver(
            forName: UIAccessibility.prefersCrossFadeTransitionsStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(crossFadeTransitionsObserver)

        let videoAutoplayObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.videoAutoplayStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(videoAutoplayObserver)

        let differentiateWithoutColorObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.differentiateWithoutColorDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(differentiateWithoutColorObserver)

        let onOffSwitchLabelsObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.onOffSwitchLabelsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(onOffSwitchLabelsObserver)

        let voiceOverObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(voiceOverObserver)

        let switchControlObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.switchControlStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(switchControlObserver)

        let assistiveTouchObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.assistiveTouchStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(assistiveTouchObserver)

        let boldTextObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.boldTextStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(boldTextObserver)

        let closedCaptioningObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.closedCaptioningStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(closedCaptioningObserver)

        let reduceTransparencyObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(reduceTransparencyObserver)

        let reduceMotionObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(reduceMotionObserver)

        let invertColorsObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.invertColorsStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(invertColorsObserver)

        let increaseContrastObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(increaseContrastObserver)

        let monoAudioObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.monoAudioStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(monoAudioObserver)

        let shakeToUndoObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.shakeToUndoDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(shakeToUndoObserver)

        let grayscaleObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.grayscaleStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(grayscaleObserver)

        let guidedAccessObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.guidedAccessStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(guidedAccessObserver)

        let speakScreenObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.speakScreenStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(speakScreenObserver)

        let speakSelectionObserver = notificationCenter.addObserver(
            forName: KubesenseAccessibility.speakSelectionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
        observers.append(speakSelectionObserver)
        #endif
    }

    private func stopObserving() {
        observers.forEach { notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    @MainActor private var currentState: AccessibilityInfo {
        var state = AccessibilityInfo()

        #if canImport(UIKit)
        if let contentSize = UIApplication.kubesense.managedShared?.preferredContentSizeCategory.rawValue as String? {
            state.textSize = contentSize
        } else {
            state.textSize = UIContentSizeCategory.unspecified.rawValue
        }

        state.videoAutoplayEnabled = KubesenseAccessibility.isVideoAutoplayEnabled
        state.shouldDifferentiateWithoutColor = KubesenseAccessibility.shouldDifferentiateWithoutColor
        state.onOffSwitchLabelsEnabled = KubesenseAccessibility.isOnOffSwitchLabelsEnabled
        state.screenReaderEnabled = KubesenseAccessibility.isVoiceOverRunning
        state.boldTextEnabled = KubesenseAccessibility.isBoldTextEnabled
        state.reduceTransparencyEnabled = KubesenseAccessibility.isReduceTransparencyEnabled
        state.reduceMotionEnabled = KubesenseAccessibility.isReduceMotionEnabled
        state.invertColorsEnabled = KubesenseAccessibility.isInvertColorsEnabled
        state.increaseContrastEnabled = KubesenseAccessibility.isDarkerSystemColorsEnabled
        state.assistiveSwitchEnabled = KubesenseAccessibility.isSwitchControlRunning
        state.assistiveTouchEnabled = KubesenseAccessibility.isAssistiveTouchRunning
        state.closedCaptioningEnabled = KubesenseAccessibility.isClosedCaptioningEnabled
        state.monoAudioEnabled = KubesenseAccessibility.isMonoAudioEnabled
        state.shakeToUndoEnabled = KubesenseAccessibility.isShakeToUndoEnabled
        state.grayscaleEnabled = KubesenseAccessibility.isGrayscaleEnabled
        state.singleAppModeEnabled = KubesenseAccessibility.isGuidedAccessEnabled
        state.speakScreenEnabled = KubesenseAccessibility.isSpeakScreenEnabled
        state.speakSelectionEnabled = KubesenseAccessibility.isSpeakSelectionEnabled
        state.rtlEnabled = UIApplication.kubesense.managedShared?.userInterfaceLayoutDirection == .rightToLeft
        state.buttonShapesEnabled = UIAccessibility.buttonShapesEnabled
        state.reducedAnimationsEnabled = UIAccessibility.prefersCrossFadeTransitions
        #endif

        return state
    }
}

#endif
