use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum InputBehavior {
    OptionPressed,
    OptionReleased,
    OptionWindowExpired,
    TypingDetected,
    ManualSwitchDetected,
    CooldownExpired,
    VoiceExitDelayElapsed,
}

impl InputBehavior {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::OptionPressed => "optionPressed",
            Self::OptionReleased => "optionReleased",
            Self::OptionWindowExpired => "optionWindowExpired",
            Self::TypingDetected => "typingDetected",
            Self::ManualSwitchDetected => "manualSwitchDetected",
            Self::CooldownExpired => "cooldownExpired",
            Self::VoiceExitDelayElapsed => "voiceExitDelayElapsed",
        }
    }
}

impl FromStr for InputBehavior {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "optionPressed" => Ok(Self::OptionPressed),
            "optionReleased" => Ok(Self::OptionReleased),
            "optionWindowExpired" => Ok(Self::OptionWindowExpired),
            "typingDetected" => Ok(Self::TypingDetected),
            "manualSwitchDetected" => Ok(Self::ManualSwitchDetected),
            "cooldownExpired" => Ok(Self::CooldownExpired),
            "voiceExitDelayElapsed" => Ok(Self::VoiceExitDelayElapsed),
            _ => Err(format!("unknown input behavior: {value}")),
        }
    }
}
