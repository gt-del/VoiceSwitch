import ApplicationServices
import Testing
@testable import VoiceSwitchKit

struct KeyboardEventTapServiceTests {
    @Test
    func optionFlagsChangedMapsToOptionPressed() {
        let summary = KeyboardEventTapService.summary(
            for: .flagsChanged,
            keyCode: 58,
            flags: .maskAlternate
        )

        #expect(summary == .optionPressed(keyCode: 58))
        #expect(summary?.mappedBehavior == .optionPressed)
    }

    @Test
    func optionFlagsChangedWithoutAlternateMapsToOptionReleased() {
        let summary = KeyboardEventTapService.summary(
            for: .flagsChanged,
            keyCode: 61,
            flags: []
        )

        #expect(summary == .optionReleased(keyCode: 61))
        #expect(summary?.mappedBehavior == .optionReleased)
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
