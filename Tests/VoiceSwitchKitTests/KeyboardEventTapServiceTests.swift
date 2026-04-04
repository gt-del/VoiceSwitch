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
        #expect(summary?.mappedBehavior == .controlPressed)
        #expect(summary?.rawDescription == "controlDown(keyCode:59)")
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
        #expect(summary?.rawDescription == "controlUp(keyCode:59)")
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
}
