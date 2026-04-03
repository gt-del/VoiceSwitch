use std::str::FromStr;

use thiserror::Error;
use voiceswitch_core::engine::transition;
use voiceswitch_core::event::InputBehavior;
use voiceswitch_core::state::EngineState;

#[derive(Debug, Error)]
enum CliError {
    #[error("expected 2 arguments: <state> <event>")]
    MissingArguments,
    #[error("{0}")]
    InvalidState(String),
    #[error("{0}")]
    InvalidEvent(String),
    #[error("failed to serialize transition result: {0}")]
    Serialize(#[from] serde_json::Error),
}

fn main() -> Result<(), CliError> {
    let mut args = std::env::args().skip(1);
    let state = args.next().ok_or(CliError::MissingArguments)?;
    let event = args.next().ok_or(CliError::MissingArguments)?;

    let current_state = EngineState::from_str(&state).map_err(CliError::InvalidState)?;
    let input_behavior = InputBehavior::from_str(&event).map_err(CliError::InvalidEvent)?;
    let result = transition(current_state, input_behavior);
    let output = serde_json::to_string(&result)?;

    println!("{output}");

    Ok(())
}
