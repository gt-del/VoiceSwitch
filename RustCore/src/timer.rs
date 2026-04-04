use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EngineTimerKind {
    OptionPendingWindow,
    VoiceExitDelay,
    Cooldown,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineTimer {
    pub kind: EngineTimerKind,
    pub delay_seconds: f64,
}

impl EngineTimer {
    pub fn new(kind: EngineTimerKind, delay_seconds: f64) -> Self {
        Self {
            kind,
            delay_seconds,
        }
    }
}
