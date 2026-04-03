use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum InputBehavior {
    OptionPressed,
    OptionReleased,
    TypingDetected,
    ManualSwitchDetected,
    CooldownExpired,
}

impl InputBehavior {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::OptionPressed => "optionPressed",
            Self::OptionReleased => "optionReleased",
            Self::TypingDetected => "typingDetected",
            Self::ManualSwitchDetected => "manualSwitchDetected",
            Self::CooldownExpired => "cooldownExpired",
        }
    }
}

impl FromStr for InputBehavior {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "optionPressed" => Ok(Self::OptionPressed),
            "optionReleased" => Ok(Self::OptionReleased),
            "typingDetected" => Ok(Self::TypingDetected),
            "manualSwitchDetected" => Ok(Self::ManualSwitchDetected),
            "cooldownExpired" => Ok(Self::CooldownExpired),
            _ => Err(format!("unknown input behavior: {value}")),
        }
    }
}
