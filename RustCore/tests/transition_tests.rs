use voiceswitch_core::action::EngineAction;
use voiceswitch_core::engine::transition;
use voiceswitch_core::event::InputBehavior;
use voiceswitch_core::state::EngineState;

#[test]
fn option_press_moves_idle_to_option_pending() {
    let result = transition(EngineState::IdlePrimary, InputBehavior::OptionPressed);

    assert_eq!(result.state, EngineState::OptionPending);
    assert_eq!(result.action, EngineAction::NoOp);
}

#[test]
fn option_release_moves_option_pending_to_voice_active() {
    let result = transition(EngineState::OptionPending, InputBehavior::OptionReleased);

    assert_eq!(result.state, EngineState::VoiceActive);
    assert_eq!(result.action, EngineAction::SwitchToVoice);
}

#[test]
fn typing_detected_moves_voice_active_back_to_idle_primary() {
    let result = transition(EngineState::VoiceActive, InputBehavior::TypingDetected);

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::SwitchToPrimary);
}

#[test]
fn manual_switch_enters_cooldown() {
    let result = transition(EngineState::IdlePrimary, InputBehavior::ManualSwitchDetected);

    assert_eq!(result.state, EngineState::Cooldown);
    assert_eq!(result.action, EngineAction::EnterCooldown);
}

#[test]
fn cooldown_expired_returns_to_idle_primary() {
    let result = transition(EngineState::Cooldown, InputBehavior::CooldownExpired);

    assert_eq!(result.state, EngineState::IdlePrimary);
    assert_eq!(result.action, EngineAction::NoOp);
}
