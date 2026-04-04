use crate::action::EngineAction;
use crate::config::{EngineConfiguration, TypingKeyCategory};
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
            state: EngineState::OptionPending,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                "optionPressed",
                "entered_option_pending",
                EngineState::IdlePrimary,
                EngineState::OptionPending,
            ),
            timer: Some(EngineTimer::new(
                EngineTimerKind::OptionPendingWindow,
                configuration.option_pending_window,
            )),
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
            timer: None,
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
            timer: None,
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
            timer: None,
        },
        (EngineState::OptionPending, event) if is_typing_key_event(event) => {
            typing_key_transition(
                EngineState::OptionPending,
                EngineAction::NoOp,
                EngineState::IdlePrimary,
                event,
                configuration,
            )
        }
        (EngineState::VoiceActive, InputBehavior::OptionReleased) => EngineTransition {
            state: EngineState::VoiceActive,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                "optionReleased",
                "awaiting_voice_exit_delay",
                EngineState::VoiceActive,
                EngineState::VoiceActive,
            ),
            timer: Some(EngineTimer::new(
                EngineTimerKind::VoiceExitDelay,
                configuration.voice_exit_delay,
            )),
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
            timer: None,
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
            timer: None,
        },
        (EngineState::VoiceActive, event) if is_typing_key_event(event) => {
            typing_key_transition(
                EngineState::VoiceActive,
                EngineAction::SwitchToPrimary,
                EngineState::IdlePrimary,
                event,
                configuration,
            )
        }
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

fn is_typing_key_event(event: InputBehavior) -> bool {
    typing_key_category(event).is_some()
}

fn typing_key_category(event: InputBehavior) -> Option<TypingKeyCategory> {
    match event {
        InputBehavior::TypingKeyLetters => Some(TypingKeyCategory::Letters),
        InputBehavior::TypingKeyNumbers => Some(TypingKeyCategory::Numbers),
        InputBehavior::TypingKeySpace => Some(TypingKeyCategory::Space),
        InputBehavior::TypingKeyDelete => Some(TypingKeyCategory::Delete),
        InputBehavior::TypingKeyReturnKey => Some(TypingKeyCategory::ReturnKey),
        _ => None,
    }
}

fn typing_key_transition(
    source_state: EngineState,
    allowed_action: EngineAction,
    allowed_target_state: EngineState,
    event: InputBehavior,
    configuration: &EngineConfiguration,
) -> EngineTransition {
    let category = typing_key_category(event).expect("typing key category must exist");
    let category_name = category_name(category);

    if configuration.typing_key_whitelist.contains(&category) {
        EngineTransition {
            state: allowed_target_state,
            action: allowed_action,
            diagnostic: DiagnosticEntry::new(
                event.as_str(),
                format!("typing_key_whitelisted_{category_name}"),
                source_state,
                allowed_target_state,
            ),
            timer: None,
        }
    } else {
        EngineTransition {
            state: source_state,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(
                event.as_str(),
                format!("typing_key_not_whitelisted_{category_name}"),
                source_state,
                source_state,
            ),
            timer: None,
        }
    }
}

fn category_name(category: TypingKeyCategory) -> &'static str {
    match category {
        TypingKeyCategory::Letters => "letters",
        TypingKeyCategory::Numbers => "numbers",
        TypingKeyCategory::Space => "space",
        TypingKeyCategory::Delete => "delete",
        TypingKeyCategory::ReturnKey => "return_key",
    }
}
