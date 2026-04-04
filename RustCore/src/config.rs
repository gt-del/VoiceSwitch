use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineConfiguration {
    pub voice_activation_delay: f64,
    pub release_return_delay: f64,
    pub cooldown_duration: f64,
    pub typing_key_whitelist: Vec<TypingKeyCategory>,
}

impl Default for EngineConfiguration {
    fn default() -> Self {
        Self {
            voice_activation_delay: 0.0,
            release_return_delay: 0.0,
            cooldown_duration: 5.0,
            typing_key_whitelist: vec![
                TypingKeyCategory::Letters,
                TypingKeyCategory::Numbers,
                TypingKeyCategory::Space,
                TypingKeyCategory::Delete,
                TypingKeyCategory::ReturnKey,
            ],
        }
    }
}

impl EngineConfiguration {
    pub fn validate(&self) -> Result<(), EngineConfigurationError> {
        validate_duration(
            self.voice_activation_delay,
            0.0,
            0.3,
            "voiceActivationDelay",
        )?;
        validate_duration(
            self.release_return_delay,
            0.0,
            0.3,
            "releaseReturnDelay",
        )?;
        validate_duration(self.cooldown_duration, 0.5, 30.0, "cooldownDuration")?;

        if self.typing_key_whitelist.is_empty() {
            return Err(EngineConfigurationError::EmptyTypingKeyWhitelist);
        }

        Ok(())
    }
}

fn validate_duration(
    value: f64,
    min: f64,
    max: f64,
    field_name: &'static str,
) -> Result<(), EngineConfigurationError> {
    if !value.is_finite() {
        return Err(EngineConfigurationError::NonFinite(field_name));
    }

    if value < min || value > max {
        return Err(EngineConfigurationError::OutOfRange {
            field_name,
            min,
            max,
            actual: value,
        });
    }

    Ok(())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TypingKeyCategory {
    Letters,
    Numbers,
    Space,
    Delete,
    ReturnKey,
}

#[derive(Debug, Error)]
pub enum EngineConfigurationError {
    #[error("{0} must be finite")]
    NonFinite(&'static str),
    #[error("{field_name} must be within {min}...{max}, got {actual}")]
    OutOfRange {
        field_name: &'static str,
        min: f64,
        max: f64,
        actual: f64,
    },
    #[error("typingKeyWhitelist must not be empty")]
    EmptyTypingKeyWhitelist,
}
