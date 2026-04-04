use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EngineState {
    IdlePrimary,
    VoiceMode,
    Cooldown,
}

impl EngineState {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::IdlePrimary => "idlePrimary",
            Self::VoiceMode => "voiceMode",
            Self::Cooldown => "cooldown",
        }
    }
}

impl FromStr for EngineState {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "idlePrimary" => Ok(Self::IdlePrimary),
            "voiceMode" => Ok(Self::VoiceMode),
            "cooldown" => Ok(Self::Cooldown),
            _ => Err(format!("unknown engine state: {value}")),
        }
    }
}
