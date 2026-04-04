use voiceswitch_core::action::EngineAction;
use voiceswitch_core::config::EngineConfiguration;
use voiceswitch_core::engine::transition;
use voiceswitch_core::event::InputBehavior;
use voiceswitch_core::state::EngineState;
use voiceswitch_core::timer::EngineTimerKind;

#[test]
fn primary_transition_matrix_remains_stable() {
    let configuration = EngineConfiguration::default();
    let cases = [
        (
            EngineState::IdlePrimary,
            InputBehavior::ControlPressed,
            EngineState::VoiceMode,
            EngineAction::SwitchToVoice,
            "pressed_control_switch_to_voice",
        ),
        (
            EngineState::VoiceMode,
            InputBehavior::ControlPressed,
            EngineState::IdlePrimary,
            EngineAction::SwitchToPrimary,
            "pressed_control_switch_to_primary",
        ),
        (
            EngineState::IdlePrimary,
            InputBehavior::ManualSwitchDetected,
            EngineState::Cooldown,
            EngineAction::EnterCooldown,
            "entered_cooldown_after_manual_switch",
        ),
        (
            EngineState::Cooldown,
            InputBehavior::CooldownExpired,
            EngineState::IdlePrimary,
            EngineAction::NoOp,
            "cooldown_expired",
        ),
    ];

    for (source_state, event, target_state, action, reason) in cases {
        let result = transition(source_state, event, &configuration);
        assert_eq!(result.state, target_state);
        assert_eq!(result.action, action);
        assert_eq!(result.diagnostic.source_state, source_state);
        assert_eq!(result.diagnostic.target_state, target_state);
        assert_eq!(result.diagnostic.reason, reason);
    }
}

#[test]
fn control_toggle_manual_switch_and_cooldown_sequence_stays_stable() {
    let configuration = EngineConfiguration::default();

    let pressed = transition(
        EngineState::IdlePrimary,
        InputBehavior::ControlPressed,
        &configuration,
    );
    assert_eq!(pressed.state, EngineState::VoiceMode);
    assert_eq!(pressed.action, EngineAction::SwitchToVoice);

    let manual = transition(
        pressed.state,
        InputBehavior::ManualSwitchDetected,
        &configuration,
    );
    assert_eq!(manual.state, EngineState::Cooldown);
    assert_eq!(manual.action, EngineAction::EnterCooldown);

    let expired = transition(
        manual.state,
        InputBehavior::CooldownExpired,
        &configuration,
    );
    assert_eq!(expired.state, EngineState::IdlePrimary);
    assert_eq!(expired.action, EngineAction::NoOp);

    let pressed_after_cooldown = transition(
        expired.state,
        InputBehavior::ControlPressed,
        &configuration,
    );
    assert_eq!(pressed_after_cooldown.state, EngineState::VoiceMode);
    assert_eq!(pressed_after_cooldown.action, EngineAction::SwitchToVoice);
    assert_eq!(
        pressed_after_cooldown.diagnostic.reason,
        "pressed_control_switch_to_voice"
    );
}

#[test]
fn control_press_moves_idle_primary_to_voice_mode_and_switches_to_voice() {
    let result = transition(
        EngineState::IdlePrimary,
        InputBehavior::ControlPressed,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::VoiceMode);
    assert_eq!(result.action, EngineAction::SwitchToVoice);
    assert_eq!(result.diagnostic.trigger, "controlPressed");
    assert_eq!(result.diagnostic.reason, "pressed_control_switch_to_voice");
    assert_eq!(result.timer, None);
}

#[test]
fn second_control_press_moves_voice_mode_back_to_idle_primary_and_switches_to_primary() {
    let result = transition(
        EngineState::VoiceMode,
        InputBehavior::ControlPressed,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::SwitchToPrimary);
    assert_eq!(result.diagnostic.trigger, "controlPressed");
    assert_eq!(result.diagnostic.reason, "pressed_control_switch_to_primary");
    assert_eq!(result.timer, None);
}

#[test]
fn control_release_does_not_drive_main_toggle_path() {
    let result = transition(
        EngineState::VoiceMode,
        InputBehavior::ControlReleased,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::VoiceMode);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.trigger, "controlReleased");
    assert_eq!(result.diagnostic.reason, "ignored_event_in_current_state");
    assert_eq!(result.timer, None);
}

#[test]
fn manual_switch_enters_cooldown_with_configured_timer() {
    let configuration = EngineConfiguration {
        cooldown_duration: 9.0,
        ..EngineConfiguration::default()
    };
    let result = transition(
        EngineState::VoiceMode,
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
fn typing_key_events_do_not_drive_main_path_when_voice_mode_is_active() {
    let result = transition(
        EngineState::VoiceMode,
        InputBehavior::TypingKeyLetters,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::VoiceMode);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.reason, "ignored_event_in_current_state");
}

#[test]
fn cooldown_ignores_control_press_until_expired() {
    let result = transition(
        EngineState::Cooldown,
        InputBehavior::ControlPressed,
        &EngineConfiguration::default(),
    );

    assert_eq!(result.state, EngineState::Cooldown);
    assert_eq!(result.action, EngineAction::NoOp);
    assert_eq!(result.diagnostic.reason, "ignored_event_in_current_state");
}
