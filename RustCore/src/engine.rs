use crate::action::EngineAction;
use crate::diagnostics::DiagnosticEntry;
use crate::event::InputBehavior;
use crate::state::EngineState;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EngineTransition {
    pub state: EngineState,
    pub action: EngineAction,
    pub diagnostic: DiagnosticEntry,
}

pub fn transition(_current: EngineState, _event: InputBehavior) -> EngineTransition {
    todo!("stage 2 transition logic not implemented yet")
}
