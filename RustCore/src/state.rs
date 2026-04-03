use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum EngineState {
    IdlePrimary,
    OptionPending,
    VoiceActive,
    Cooldown,
}

impl EngineState {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::IdlePrimary => "idlePrimary",
            Self::OptionPending => "optionPending",
            Self::VoiceActive => "voiceActive",
            Self::Cooldown => "cooldown",
        }
    }
}

impl FromStr for EngineState {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "idlePrimary" => Ok(Self::IdlePrimary),
            "optionPending" => Ok(Self::OptionPending),
            "voiceActive" => Ok(Self::VoiceActive),
            "cooldown" => Ok(Self::Cooldown),
            _ => Err(format!("unknown engine state: {value}")),
        }
    }
}
