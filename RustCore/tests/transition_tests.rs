use voiceswitch_core::action::EngineAction;
use voiceswitch_core::config::EngineConfiguration;
use voiceswitch_core::engine::transition;
use voiceswitch_core::event::InputBehavior;
use voiceswitch_core::state::EngineState;
use voiceswitch_core::timer::EngineTimerKind;

#[test]
fn option_press_moves_idle_primary_to_voice_held_and_switches_to_voice() {
    let result = transition(
        EngineState::IdlePrimary,
        InputBehavior::OptionPressed,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::VoiceHeld);
    assert_eq!(result.action, EngineAction::SwitchToVoice);
    assert_eq!(result.diagnostic.trigger, "optionPressed");
    assert_eq!(result.diagnostic.reason, "pressed_option_switch_to_voice");
    assert_eq!(result.timer, None);
}

#[test]
fn option_release_moves_voice_held_back_to_idle_primary_and_switches_to_primary() {
    let result = transition(
        EngineState::VoiceHeld,
        InputBehavior::OptionReleased,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::SwitchToPrimary);
    assert_eq!(result.diagnostic.trigger, "optionReleased");
    assert_eq!(result.diagnostic.reason, "released_option_switch_to_primary");
    assert_eq!(result.timer, None);
}

#[test]
fn manual_switch_enters_cooldown_with_configured_timer() {
    let configuration = EngineConfiguration {
        cooldown_duration: 9.0,
        ..EngineConfiguration::default()
    };
    let result = transition(
        EngineState::VoiceHeld,
        InputBehavior::ManualSwitchDetected,
        &configuration,
    );

    assert_eq!(result.state, EngineState::Cooldown);
    assert_eq!(result.action, EngineAction::EnterCooldown);
    assert_eq!(
        result.timer.as_ref().map(|timer| timer.kind),
        Some(EngineTimerKind::Cooldown)
    );
    assert_eq!(
        result.timer.as_ref().map(|timer| timer.delay_seconds),
        Some(9.0)
    );
    assert_eq!(
        result.diagnostic.reason,
        "entered_cooldown_after_manual_switch"
    );
}

#[test]
fn cooldown_expired_returns_to_idle_primary_without_switch_action() {
    let result = transition(
        EngineState::Cooldown,
        InputBehavior::CooldownExpired,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.reason, "cooldown_expired");
}

#[test]
fn typing_key_events_do_not_drive_main_path_when_voice_is_held() {
    let result = transition(
        EngineState::VoiceHeld,
        InputBehavior::TypingKeyLetters,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::VoiceHeld);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.reason, "ignored_event_in_current_state");
}

#[test]
fn cooldown_ignores_option_press_until_expired() {
    let result = transition(
        EngineState::Cooldown,
        InputBehavior::OptionPressed,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::Cooldown);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.reason, "ignored_event_in_current_state");
}
