use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum InputBehavior {
    ControlPressed,
    ControlReleased,
    TypingDetected,
    TypingKeyLetters,
    TypingKeyNumbers,
    TypingKeySpace,
    TypingKeyDelete,
    TypingKeyReturnKey,
    ManualSwitchDetected,
    CooldownExpired,
}

impl InputBehavior {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::ControlPressed => "controlPressed",
            Self::ControlReleased => "controlReleased",
            Self::TypingDetected => "typingDetected",
            Self::TypingKeyLetters => "typingKeyLetters",
            Self::TypingKeyNumbers => "typingKeyNumbers",
            Self::TypingKeySpace => "typingKeySpace",
            Self::TypingKeyDelete => "typingKeyDelete",
            Self::TypingKeyReturnKey => "typingKeyReturnKey",
            Self::ManualSwitchDetected => "manualSwitchDetected",
            Self::CooldownExpired => "cooldownExpired",
        }
    }
}

impl FromStr for InputBehavior {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "controlPressed" => Ok(Self::ControlPressed),
            "controlReleased" => Ok(Self::ControlReleased),
            "typingDetected" => Ok(Self::TypingDetected),
            "typingKeyLetters" => Ok(Self::TypingKeyLetters),
            "typingKeyNumbers" => Ok(Self::TypingKeyNumbers),
            "typingKeySpace" => Ok(Self::TypingKeySpace),
            "typingKeyDelete" => Ok(Self::TypingKeyDelete),
            "typingKeyReturnKey" => Ok(Self::TypingKeyReturnKey),
            "manualSwitchDetected" => Ok(Self::ManualSwitchDetected),
            "cooldownExpired" => Ok(Self::CooldownExpired),
            _ => Err(format!("unknown input behavior: {value}")),
        }
    }
}
