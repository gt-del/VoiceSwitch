use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EngineAction {
    SwitchToPrimary,
    SwitchToVoice,
    EnterCooldown,
    NoOp,
}
