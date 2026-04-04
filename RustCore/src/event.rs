use serde::{Deserialize, Serialize};
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum InputBehavior {
    OptionPressed,
    OptionReleased,
    OptionWindowExpired,
    TypingDetected,
    TypingKeyLetters,
    TypingKeyNumbers,
    TypingKeySpace,
    TypingKeyDelete,
    TypingKeyReturnKey,
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
            Self::TypingKeyLetters => "typingKeyLetters",
            Self::TypingKeyNumbers => "typingKeyNumbers",
            Self::TypingKeySpace => "typingKeySpace",
            Self::TypingKeyDelete => "typingKeyDelete",
            Self::TypingKeyReturnKey => "typingKeyReturnKey",
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
            "typingKeyLetters" => Ok(Self::TypingKeyLetters),
            "typingKeyNumbers" => Ok(Self::TypingKeyNumbers),
            "typingKeySpace" => Ok(Self::TypingKeySpace),
            "typingKeyDelete" => Ok(Self::TypingKeyDelete),
            "typingKeyReturnKey" => Ok(Self::TypingKeyReturnKey),
            "manualSwitchDetected" => Ok(Self::ManualSwitchDetected),
            "cooldownExpired" => Ok(Self::CooldownExpired),
            "voiceExitDelayElapsed" => Ok(Self::VoiceExitDelayElapsed),
            _ => Err(format!("unknown input behavior: {value}")),
        }
    }
}
