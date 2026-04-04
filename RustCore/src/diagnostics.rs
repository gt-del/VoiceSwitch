use crate::state::EngineState;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DiagnosticEntry {
    pub trigger: String,
    pub reason: String,
    pub source_state: EngineState,
    pub target_state: EngineState,
}

impl DiagnosticEntry {
    pub fn new(
        trigger: impl Into<String>,
        reason: impl Into<String>,
        source_state: EngineState,
        target_state: EngineState,
    ) -> Self {
        Self {
            trigger: trigger.into(),
            reason: reason.into(),
            source_state,
            target_state,
        }
    }
}
