use voiceswitch_core::action::EngineAction;
use voiceswitch_core::config::EngineConfiguration;
use voiceswitch_core::engine::transition;
use voiceswitch_core::event::InputBehavior;
use voiceswitch_core::state::EngineState;

#[test]
fn option_press_moves_idle_to_option_pending() {
    let result = transition(
        EngineState::IdlePrimary,
        InputBehavior::OptionPressed,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::OptionPending);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.trigger, "optionPressed");
    assert_eq!(result.diagnostic.reason, "entered_option_pending");
}

#[test]
fn option_window_expired_moves_option_pending_to_voice_active() {
    let result = transition(
        EngineState::OptionPending,
        InputBehavior::OptionWindowExpired,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::VoiceActive);
    assert_eq!(result.action, EngineAction::SwitchToVoice);
}

#[test]
fn typing_detected_moves_voice_active_back_to_idle_primary() {
    let result = transition(
        EngineState::VoiceActive,
        InputBehavior::TypingDetected,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::SwitchToPrimary);
}

#[test]
fn manual_switch_enters_cooldown() {
    let result = transition(
        EngineState::IdlePrimary,
        InputBehavior::ManualSwitchDetected,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::Cooldown);
    assert_eq!(result.action, EngineAction::EnterCooldown);
}

#[test]
fn cooldown_expired_returns_to_idle_primary() {
    let result = transition(
        EngineState::Cooldown,
        InputBehavior::CooldownExpired,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::NoOp);
}

#[test]
fn option_release_before_window_expiry_returns_to_idle_primary() {
    let result = transition(
        EngineState::OptionPending,
        InputBehavior::OptionReleased,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.reason, "released_before_option_window_expired");
}

#[test]
fn voice_exit_delay_elapsed_returns_voice_active_to_idle_primary() {
    let result = transition(
        EngineState::VoiceActive,
        InputBehavior::VoiceExitDelayElapsed,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::SwitchToPrimary);
    assert_eq!(result.diagnostic.reason, "voice_exit_delay_elapsed");
}
