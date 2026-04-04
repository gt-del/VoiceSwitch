use crate::action::EngineAction;
use crate::config::EngineConfiguration;
use crate::diagnostics::DiagnosticEntry;
use crate::event::InputBehavior;
use crate::state::EngineState;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct EngineTransition {
    pub state: EngineState,
    pub action: EngineAction,
    pub diagnostic: DiagnosticEntry,
}

pub fn transition(
    current: EngineState,
    event: InputBehavior,
    _configuration: &EngineConfiguration,
) -> EngineTransition {
    match (current, event) {
        (EngineState::IdlePrimary, InputBehavior::OptionPressed) => EngineTransition {
            state: EngineState::OptionPending,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                "optionPressed",
                "entered_option_pending",
                EngineState::IdlePrimary,
                EngineState::OptionPending,
            ),
        },
        (EngineState::OptionPending, InputBehavior::OptionWindowExpired) => EngineTransition {
            state: EngineState::VoiceActive,
            action: EngineAction::SwitchToVoice,
            diagnostic: DiagnosticEntry::new(
                "optionWindowExpired",
                "activated_voice_after_option_window",
                EngineState::OptionPending,
                EngineState::VoiceActive,
            ),
        },
        (EngineState::OptionPending, InputBehavior::OptionReleased) => EngineTransition {
            state: EngineState::IdlePrimary,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                "optionReleased",
                "released_before_option_window_expired",
                EngineState::OptionPending,
                EngineState::IdlePrimary,
            ),
        },
        (EngineState::OptionPending, InputBehavior::TypingDetected) => EngineTransition {
            state: EngineState::IdlePrimary,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                "typingDetected",
                "cancelled_option_pending_due_to_typing",
                EngineState::OptionPending,
                EngineState::IdlePrimary,
            ),
        },
        (EngineState::VoiceActive, InputBehavior::OptionReleased) => EngineTransition {
            state: EngineState::VoiceActive,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                "optionReleased",
                "awaiting_voice_exit_delay",
                EngineState::VoiceActive,
                EngineState::VoiceActive,
            ),
        },
        (EngineState::VoiceActive, InputBehavior::VoiceExitDelayElapsed) => EngineTransition {
            state: EngineState::IdlePrimary,
            action: EngineAction::SwitchToPrimary,
            diagnostic: DiagnosticEntry::new(
                "voiceExitDelayElapsed",
                "voice_exit_delay_elapsed",
                EngineState::VoiceActive,
                EngineState::IdlePrimary,
            ),
        },
        (EngineState::VoiceActive, InputBehavior::TypingDetected) => EngineTransition {
            state: EngineState::IdlePrimary,
            action: EngineAction::SwitchToPrimary,
            diagnostic: DiagnosticEntry::new(
                "typingDetected",
                "returned_to_idle_primary_after_typing",
                EngineState::VoiceActive,
                EngineState::IdlePrimary,
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
        },
    }
}
