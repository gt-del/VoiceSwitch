use crate::action::EngineAction;
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

pub fn transition(current: EngineState, event: InputBehavior) -> EngineTransition {
    match (current, event) {
        (EngineState::IdlePrimary, InputBehavior::OptionPressed) => EngineTransition {
            state: EngineState::OptionPending,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new("Entered optionPending"),
        },
        (EngineState::OptionPending, InputBehavior::OptionReleased) => EngineTransition {
            state: EngineState::VoiceActive,
            action: EngineAction::SwitchToVoice,
            diagnostic: DiagnosticEntry::new("Activated voiceActive"),
        },
        (EngineState::OptionPending, InputBehavior::TypingDetected) => EngineTransition {
            state: EngineState::IdlePrimary,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new("Cancelled optionPending due to typing"),
        },
        (EngineState::VoiceActive, InputBehavior::TypingDetected) => EngineTransition {
            state: EngineState::IdlePrimary,
            action: EngineAction::SwitchToPrimary,
            diagnostic: DiagnosticEntry::new("Returned to idlePrimary after typing"),
        },
        (_, InputBehavior::ManualSwitchDetected) => EngineTransition {
            state: EngineState::Cooldown,
            action: EngineAction::EnterCooldown,
            diagnostic: DiagnosticEntry::new("Entered cooldown after manual switch"),
        },
        (EngineState::Cooldown, InputBehavior::CooldownExpired) => EngineTransition {
            state: EngineState::IdlePrimary,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new("Cooldown expired; returned to idlePrimary"),
        },
        (state, event) => EngineTransition {
            state,
            action: EngineAction::NoOp,
            diagnostic: DiagnosticEntry::new(format!(
                "Ignored {} while in {}",
                event.as_str(),
                state.as_str()
            )),
        },
    }
}
