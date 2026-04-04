import ApplicationServices
import Testing
@testable import VoiceSwitchKit

struct KeyboardEventTapServiceTests {
    @Test
    func leftControlFlagsChangedMapsToControlPressedBehavior() {
        let summary = KeyboardEventTapService.summary(
            for: .flagsChanged,
            keyCode: 59,
            flags: .maskControl
        )

        #expect(summary == .controlPressed(keyCode: 59))
        #expect(summary?.mappedBehavior == nil)
        #expect(summary?.rawDescription == "leftControlDown(keyCode:59)")
    }

    @Test
    func leftControlFlagsChangedWithoutMaskControlMapsToControlReleasedBehavior() {
        let summary = KeyboardEventTapService.summary(
            for: .flagsChanged,
            keyCode: 59,
            flags: []
        )

        #expect(summary == .controlReleased(keyCode: 59))
        #expect(summary?.mappedBehavior == .controlReleased)
        #expect(summary?.rawDescription == "leftControlUp(keyCode:59)")
    }

    @Test
    func rightControlFlagsChangedIsIgnored() {
        let summary = KeyboardEventTapService.summary(
            for: .flagsChanged,
            keyCode: 62,
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
    func leftControlTapEmitsToggleOnlyAfterRelease() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        let downSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 59,
            flags: .maskControl
        )
        let upSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 59,
            flags: []
        )

        #expect(downSummaries == [.controlPressed(keyCode: 59)])
        #expect(upSummaries == [.controlReleased(keyCode: 59), .controlTapCompleted(keyCode: 59)])
        #expect(upSummaries.last?.mappedBehavior == .controlPressed)
        #expect(upSummaries.last?.rawDescription == "leftControlTapCompleted(keyCode:59)")
    }

    @Test
    func typingKeyDuringLeftControlCancelsTapCompletion() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        _ = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 59,
            flags: .maskControl
        )
        let typingSummaries = service.processedSummaries(
            for: .keyDown,
            keyCode: 0,
            flags: .maskControl
        )
        let releaseSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 59,
            flags: []
        )

        #expect(typingSummaries == [.typingKey(keyCode: 0, category: .letters)])
        #expect(releaseSummaries == [.controlReleased(keyCode: 59)])
    }

    @Test
    func otherModifierDuringLeftControlCancelsTapCompletion() {
        let service = KeyboardEventTapService(permissionProvider: KeyboardEventTapPermissionProvider())

        _ = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 59,
            flags: .maskControl
        )
        let modifierSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 56,
            flags: [.maskControl, .maskShift]
        )
        let releaseSummaries = service.processedSummaries(
            for: .flagsChanged,
            keyCode: 59,
            flags: .maskShift
        )

        #expect(modifierSummaries.isEmpty)
        #expect(releaseSummaries == [.controlReleased(keyCode: 59)])
    }
}

private struct KeyboardEventTapPermissionProvider: PermissionStatusProviding {
    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(accessibility: .authorized, inputMonitoring: .authorized)
    }
}
