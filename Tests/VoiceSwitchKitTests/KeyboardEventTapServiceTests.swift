import ApplicationServices
import Testing
@testable import VoiceSwitchKit

struct KeyboardEventTapServiceTests {
    @Test
    func fnFlagsChangedMapsToControlPressedBehavior() {
        let summary = KeyboardEventTapService.summary(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )

        #expect(summary == .controlPressed(keyCode: 63))
        #expect(summary?.mappedBehavior == nil)
        #expect(summary?.rawDescription == "fnDown(keyCode:63)")
    }

    @Test
    func fnFlagsChangedWithoutMaskSecondaryFnMapsToControlReleasedBehavior() {
        let summary = KeyboardEventTapService.summary(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )

        #expect(summary == .controlReleased(keyCode: 63))
        #expect(summary?.mappedBehavior == .controlReleased)
        #expect(summary?.rawDescription == "fnUp(keyCode:63)")
    }

    @Test
    func leftControlFlagsChangedIsIgnored() {
        let summary = KeyboardEventTapService.summary(
            for: .flagsChanged,
            keyCode: 59,
            flags: .maskControl
        )

        #expect(summary == nil)
    }

    @Test
    func letterKeyDownMapsToTypingCategory() {
        let summary = KeyboardEventTapService.summary(
            for: .keyDown,
            keyCode: 0,
            flags: []
        )

        #expect(summary == .typingKey(keyCode: 0, category: .letters))
        #expect(summary?.mappedBehavior == .typingKeyLetters)
    }

    @Test
    func spaceKeyDownMapsToTypingSpaceCategory() {
        let summary = KeyboardEventTapService.summary(
            for: .keyDown,
            keyCode: 49,
            flags: []
        )

        #expect(summary == .typingKey(keyCode: 49, category: .space))
        #expect(summary?.mappedBehavior == .typingKeySpace)
    }

    @Test
    func nonTypingKeyDownIsIgnored() {
        let summary = KeyboardEventTapService.summary(
            for: .keyDown,
            keyCode: 123,
            flags: []
        )

        #expect(summary == nil)
    }

    @Test
    func tapDisabledEventMapsToRecoverySignal() {
        let summary = KeyboardEventTapService.summary(
            for: .tapDisabledByTimeout,
            keyCode: 0,
            flags: []
        )

        #expect(summary == .tapDisabled(reason: "timeout"))
        #expect(summary?.mappedBehavior == nil)
    }

    @Test
    func fnDoubleTapEmitsToggleOnlyAfterSecondRelease() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        let firstDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        let firstUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )
        let secondDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        let secondUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )

        #expect(firstDownSummaries == [.controlPressed(keyCode: 63)])
        #expect(firstUpSummaries == [.controlReleased(keyCode: 63)])
        #expect(secondDownSummaries == [.controlPressed(keyCode: 63)])
        #expect(secondUpSummaries == [.controlReleased(keyCode: 63), .controlTapCompleted(keyCode: 63)])
        #expect(secondUpSummaries.last?.mappedBehavior == .controlPressed)
        #expect(secondUpSummaries.last?.rawDescription == "fnDoubleTapCompleted(keyCode:63)")
    }

    @Test
    func fnDoubleTapStillWorksWhenFlagsChangedKeyCodeIsNot63() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        let firstDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 179,
            flags: .maskSecondaryFn
        )
        let firstUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 179,
            flags: []
        )
        let secondDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 179,
            flags: .maskSecondaryFn
        )
        let secondUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 179,
            flags: []
        )

        #expect(firstDownSummaries == [.controlPressed(keyCode: 179)])
        #expect(firstUpSummaries == [.controlReleased(keyCode: 179)])
        #expect(secondDownSummaries == [.controlPressed(keyCode: 179)])
        #expect(secondUpSummaries == [.controlReleased(keyCode: 179), .controlTapCompleted(keyCode: 179)])
    }

    @Test
    func duplicateFnFlagsChangedSignalsDoNotCancelDoubleTap() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        let firstDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 179,
            flags: .maskSecondaryFn
        )
        let duplicateFirstDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        let firstUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 179,
            flags: []
        )
        let duplicateFirstUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )
        let secondDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 179,
            flags: .maskSecondaryFn
        )
        let duplicateSecondDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        let secondUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 179,
            flags: []
        )
        let duplicateSecondUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )

        #expect(firstDownSummaries == [.controlPressed(keyCode: 179)])
        #expect(duplicateFirstDownSummaries.isEmpty)
        #expect(firstUpSummaries == [.controlReleased(keyCode: 179)])
        #expect(duplicateFirstUpSummaries.isEmpty)
        #expect(secondDownSummaries == [.controlPressed(keyCode: 179)])
        #expect(duplicateSecondDownSummaries.isEmpty)
        #expect(secondUpSummaries == [.controlReleased(keyCode: 179), .controlTapCompleted(keyCode: 179)])
        #expect(duplicateSecondUpSummaries.isEmpty)
    }

    @Test
    func syntheticFnKeyDownAfterFirstTapDoesNotCancelDoubleTap() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        let firstDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        let firstUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )
        let syntheticKeyDownSummaries = service.processedSummaries(
            for: .keyDown,
            keyCode: 179,
            flags: CGEventFlags(rawValue: 256)
        )
        let secondDownSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        let secondUpSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )

        #expect(firstDownSummaries == [.controlPressed(keyCode: 63)])
        #expect(firstUpSummaries == [.controlReleased(keyCode: 63)])
        #expect(syntheticKeyDownSummaries.isEmpty)
        #expect(secondDownSummaries == [.controlPressed(keyCode: 63)])
        #expect(secondUpSummaries == [.controlReleased(keyCode: 63), .controlTapCompleted(keyCode: 63)])
    }

    @Test
    func singleFnTapDoesNotEmitToggleCompletion() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        let downSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        let upSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )

        #expect(downSummaries == [.controlPressed(keyCode: 63)])
        #expect(upSummaries == [.controlReleased(keyCode: 63)])
        #expect(!upSummaries.contains(.controlTapCompleted(keyCode: 63)))
    }

    @Test
    func typingKeyBetweenFnTapsCancelsTapCompletion() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        _ = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        _ = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )
        let typingSummaries = service.processedSummaries(
            for: .keyDown,
            keyCode: 0,
            flags: []
        )
        _ = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        let releaseSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )

        #expect(typingSummaries == [.typingKey(keyCode: 0, category: .letters)])
        #expect(releaseSummaries == [.controlReleased(keyCode: 63)])
    }

    @Test
    func otherModifierBetweenFnTapsCancelsTapCompletion() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        _ = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        _ = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )
        let modifierSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 56,
            flags: .maskShift
        )
        _ = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: .maskSecondaryFn
        )
        let releaseSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 63,
            flags: []
        )

        #expect(modifierSummaries.isEmpty)
        #expect(releaseSummaries == [.controlReleased(keyCode: 63)])
    }
}

private struct KeyboardEventTapPermissionProvider: PermissionStatusProviding {
    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)
    }
}
