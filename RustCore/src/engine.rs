use crate::action::EngineAction;
use crate::config::EngineConfiguration;
use crate::diagnostics::DiagnosticEntry;
use crate::event::InputBehavior;
use crate::state::EngineState;
use crate::timer::{EngineTimer, EngineTimerKind};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EngineTransition {
    pub state: EngineState,
    pub action: EngineAction,
    pub diagnostic: DiagnosticEntry,
    pub timer: Option<EngineTimer>,
}

pub fn transition(
    current: EngineState,
    event: InputBehavior,
    configuration: &EngineConfiguration,
) -> EngineTransition {
    match (current, event) {
        (EngineState::IdlePrimary, InputBehavior::OptionPressed) => EngineTransition {
            state: EngineState::VoiceHeld,
            action: EngineAction::SwitchToVoice,
            diagnostic: DiagnosticEntry::new(
                "optionPressed",
                "pressed_option_switch_to_voice",
                EngineState::IdlePrimary,
                EngineState::VoiceHeld,
            ),
            timer: optional_debounce_timer(
                EngineTimerKind::VoiceActivationDelay,
                configuration.voice_activation_delay,
            ),
        },
        (EngineState::VoiceHeld, InputBehavior::OptionReleased) => EngineTransition {
            state: EngineState::IdlePrimary,
            action: EngineAction::SwitchToPrimary,
            diagnostic: DiagnosticEntry::new(
                "optionReleased",
                "released_option_switch_to_primary",
                EngineState::VoiceHeld,
                EngineState::IdlePrimary,
            ),
            timer: optional_debounce_timer(
                EngineTimerKind::ReleaseReturnDelay,
                configuration.release_return_delay,
            ),
        },
        (_, InputBehavior::ManualSwitchDetected) => EngineTransition {
            state: EngineState::Cooldown,
            action: EngineAction::EnterCooldown,
            diagnostic: DiagnosticEntry::new(
                "manualSwitchDetected",
                "entered_cooldown_after_manual_switch",
                current,
                EngineState::Cooldown,
            ),
            timer: Some(EngineTimer::new(
                EngineTimerKind::Cooldown,
                configuration.cooldown_duration,
            )),
        },
        (EngineState::Cooldown, InputBehavior::CooldownExpired) => EngineTransition {
            state: EngineState::IdlePrimary,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                "cooldownExpired",
                "cooldown_expired",
                EngineState::Cooldown,
                EngineState::IdlePrimary,
            ),
            timer: None,
        },
        (EngineState::IdlePrimary, InputBehavior::TypingDetected)
        | (EngineState::VoiceHeld, InputBehavior::TypingDetected)
        | (EngineState::IdlePrimary, InputBehavior::TypingKeyLetters)
        | (EngineState::IdlePrimary, InputBehavior::TypingKeyNumbers)
        | (EngineState::IdlePrimary, InputBehavior::TypingKeySpace)
        | (EngineState::IdlePrimary, InputBehavior::TypingKeyDelete)
        | (EngineState::IdlePrimary, InputBehavior::TypingKeyReturnKey)
        | (EngineState::VoiceHeld, InputBehavior::TypingKeyLetters)
        | (EngineState::VoiceHeld, InputBehavior::TypingKeyNumbers)
        | (EngineState::VoiceHeld, InputBehavior::TypingKeySpace)
        | (EngineState::VoiceHeld, InputBehavior::TypingKeyDelete)
        | (EngineState::VoiceHeld, InputBehavior::TypingKeyReturnKey)
        | (EngineState::Cooldown, InputBehavior::OptionPressed)
        | (EngineState::Cooldown, InputBehavior::OptionReleased) => EngineTransition {
            state: current,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                event.as_str(),
                "ignored_event_in_current_state",
                current,
                current,
            ),
            timer: None,
        },
        (state, event) => EngineTransition {
            state,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                event.as_str(),
                "ignored_event_in_current_state",
                state,
                state,
            ),
            timer: None,
        },
    }
}

fn optional_debounce_timer(kind: EngineTimerKind, delay_seconds: f64) -> Option<EngineTimer> {
    if delay_seconds > 0.0 {
        Some(EngineTimer::new(kind, delay_seconds))
    } else {
        None
    }
}
