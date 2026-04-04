use voiceswitch_core::action::EngineAction;
use voiceswitch_core::config::EngineConfiguration;
use voiceswitch_core::engine::transition;
use voiceswitch_core::event::InputBehavior;
use voiceswitch_core::state::EngineState;
use voiceswitch_core::timer::EngineTimerKind;

#[test]
fn option_press_moves_idle_to_option_pending() {
    let configuration = EngineConfiguration {
        option_pending_window: 0.42,
        ..EngineConfiguration::default()
    };
    let result = transition(
        EngineState::IdlePrimary,
        InputBehavior::OptionPressed,
        &configuration,
    );

    assert_eq!(result.state, EngineState::OptionPending);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.trigger, "optionPressed");
    assert_eq!(result.diagnostic.reason, "entered_option_pending");
    assert_eq!(result.timer.as_ref().map(|timer| timer.kind), Some(EngineTimerKind::OptionPendingWindow));
    assert_eq!(result.timer.as_ref().map(|timer| timer.delay_seconds), Some(0.42));
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
    let configuration = EngineConfiguration {
        cooldown_duration: 9.0,
        ..EngineConfiguration::default()
    };
    let result = transition(
        EngineState::IdlePrimary,
        InputBehavior::ManualSwitchDetected,
        &configuration,
    );

    assert_eq!(result.state, EngineState::Cooldown);
    assert_eq!(result.action, EngineAction::EnterCooldown);
    assert_eq!(result.timer.as_ref().map(|timer| timer.kind), Some(EngineTimerKind::Cooldown));
    assert_eq!(result.timer.as_ref().map(|timer| timer.delay_seconds), Some(9.0));
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

#[test]
fn option_release_while_voice_active_uses_configured_voice_exit_delay() {
    let configuration = EngineConfiguration {
        voice_exit_delay: 1.75,
        ..EngineConfiguration::default()
    };
    let result = transition(
        EngineState::VoiceActive,
        InputBehavior::OptionReleased,
        &configuration,
    );

    assert_eq!(result.state, EngineState::VoiceActive);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.timer.as_ref().map(|timer| timer.kind), Some(EngineTimerKind::VoiceExitDelay));
    assert_eq!(result.timer.as_ref().map(|timer| timer.delay_seconds), Some(1.75));
}

#[test]
fn whitelisted_typing_category_returns_to_idle_primary() {
    let configuration = EngineConfiguration::default();
    let result = transition(
        EngineState::VoiceActive,
        InputBehavior::TypingKeyLetters,
        &configuration,
    );

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::SwitchToPrimary);
    assert_eq!(result.diagnostic.reason, "typing_key_whitelisted_letters");
}

#[test]
fn non_whitelisted_typing_category_is_ignored() {
    let configuration = EngineConfiguration {
        typing_key_whitelist: vec![voiceswitch_core::config::TypingKeyCategory::Numbers],
        ..EngineConfiguration::default()
    };
    let result = transition(
        EngineState::VoiceActive,
        InputBehavior::TypingKeyLetters,
        &configuration,
    );

    assert_eq!(result.state, EngineState::VoiceActive);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.reason, "typing_key_not_whitelisted_letters");
}
