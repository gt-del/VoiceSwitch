use crate::action::EngineAction;
use crate::config::{EngineConfiguration, TypingKeyCategory};
use crate::engine::transition;
use crate::event::InputBehavior;
use crate::state::EngineState;
use crate::timer::{EngineTimer, EngineTimerKind};
use std::ffi::CString;
use std::os::raw::c_char;

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VSState {
    IdlePrimary = 0,
    VoiceMode = 1,
    Cooldown = 2,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VSEvent {
    ControlPressed = 0,
    ControlReleased = 1,
    TypingDetected = 2,
    TypingKeyLetters = 3,
    TypingKeyNumbers = 4,
    TypingKeySpace = 5,
    TypingKeyDelete = 6,
    TypingKeyReturnKey = 7,
    ManualSwitchDetected = 8,
    CooldownExpired = 9,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VSAction {
    SwitchToPrimary = 0,
    SwitchToVoice = 1,
    EnterCooldown = 2,
    NoOp = 3,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VSTimerKind {
    VoiceActivationDelay = 0,
    PrimaryReturnDelay = 1,
    Cooldown = 2,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VSErrorCode {
    Ok = 0,
    InvalidArgument = 1,
    InvalidConfiguration = 2,
    Internal = 3,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct VSConfiguration {
    pub voice_activation_delay: f64,
    pub primary_return_delay: f64,
    pub cooldown_duration: f64,
    pub allow_letters: bool,
    pub allow_numbers: bool,
    pub allow_space: bool,
    pub allow_delete: bool,
    pub allow_return_key: bool,
}

#[repr(C)]
#[derive(Debug)]
pub struct VSDiagnostic {
    pub trigger: *mut c_char,
    pub reason: *mut c_char,
    pub source_state: VSState,
    pub target_state: VSState,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct VSTimer {
    pub has_value: bool,
    pub kind: VSTimerKind,
    pub delay_seconds: f64,
}

#[repr(C)]
#[derive(Debug)]
pub struct VSTransitionResult {
    pub state: VSState,
    pub action: VSAction,
    pub diagnostic: VSDiagnostic,
    pub timer: VSTimer,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rs_engine_transition(
    current_state: VSState,
    event: VSEvent,
    configuration: VSConfiguration,
    out_result: *mut VSTransitionResult,
) -> VSErrorCode {
    if out_result.is_null() {
        return VSErrorCode::InvalidArgument;
    }

    let configuration = build_configuration(configuration);
    if configuration.validate().is_err() {
        return VSErrorCode::InvalidConfiguration;
    }

    let transition = transition(
        current_state.into(),
        event.into(),
        &configuration,
    );

    let trigger = match CString::new(transition.diagnostic.trigger) {
        Ok(value) => value,
        Err(_) => return VSErrorCode::Internal,
    };
    let reason = match CString::new(transition.diagnostic.reason) {
        Ok(value) => value,
        Err(_) => return VSErrorCode::Internal,
    };

    let ffi_result = VSTransitionResult {
        state: transition.state.into(),
        action: transition.action.into(),
        diagnostic: VSDiagnostic {
            trigger: trigger.into_raw(),
            reason: reason.into_raw(),
            source_state: transition.diagnostic.source_state.into(),
            target_state: transition.diagnostic.target_state.into(),
        },
        timer: transition
            .timer
            .map(Into::into)
            .unwrap_or(VSTimer {
                has_value: false,
                kind: VSTimerKind::Cooldown,
                delay_seconds: 0.0,
            }),
    };

    // SAFETY: out_result is checked for null above and points to caller-owned writable memory.
    unsafe { out_result.write(ffi_result) };
    VSErrorCode::Ok
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn rs_transition_result_free(result: *mut VSTransitionResult) {
    if result.is_null() {
        return;
    }

    // SAFETY: pointer validity is guaranteed by caller according to FFI contract.
    let result = unsafe { &mut *result };
    if !result.diagnostic.trigger.is_null() {
        // SAFETY: allocated with CString::into_raw in rs_engine_transition.
        let _ = unsafe { CString::from_raw(result.diagnostic.trigger) };
        result.diagnostic.trigger = std::ptr::null_mut();
    }
    if !result.diagnostic.reason.is_null() {
        // SAFETY: allocated with CString::into_raw in rs_engine_transition.
        let _ = unsafe { CString::from_raw(result.diagnostic.reason) };
        result.diagnostic.reason = std::ptr::null_mut();
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn rs_error_message(code: VSErrorCode) -> *const c_char {
    static OK: &[u8] = b"ok\0";
    static INVALID_ARGUMENT: &[u8] = b"invalid argument\0";
    static INVALID_CONFIGURATION: &[u8] = b"invalid configuration\0";
    static INTERNAL: &[u8] = b"internal ffi error\0";

    match code {
        VSErrorCode::Ok => OK.as_ptr().cast(),
        VSErrorCode::InvalidArgument => INVALID_ARGUMENT.as_ptr().cast(),
        VSErrorCode::InvalidConfiguration => INVALID_CONFIGURATION.as_ptr().cast(),
        VSErrorCode::Internal => INTERNAL.as_ptr().cast(),
    }
}

fn build_configuration(configuration: VSConfiguration) -> EngineConfiguration {
    let mut typing_key_whitelist = Vec::new();
    if configuration.allow_letters {
        typing_key_whitelist.push(TypingKeyCategory::Letters);
    }
    if configuration.allow_numbers {
        typing_key_whitelist.push(TypingKeyCategory::Numbers);
    }
    if configuration.allow_space {
        typing_key_whitelist.push(TypingKeyCategory::Space);
    }
    if configuration.allow_delete {
        typing_key_whitelist.push(TypingKeyCategory::Delete);
    }
    if configuration.allow_return_key {
        typing_key_whitelist.push(TypingKeyCategory::ReturnKey);
    }

    EngineConfiguration {
        voice_activation_delay: configuration.voice_activation_delay,
        primary_return_delay: configuration.primary_return_delay,
        cooldown_duration: configuration.cooldown_duration,
        typing_key_whitelist,
    }
}

impl From<VSState> for EngineState {
    fn from(value: VSState) -> Self {
        match value {
            VSState::IdlePrimary => Self::IdlePrimary,
            VSState::VoiceMode => Self::VoiceMode,
            VSState::Cooldown => Self::Cooldown,
        }
    }
}

impl From<EngineState> for VSState {
    fn from(value: EngineState) -> Self {
        match value {
            EngineState::IdlePrimary => Self::IdlePrimary,
            EngineState::VoiceMode => Self::VoiceMode,
            EngineState::Cooldown => Self::Cooldown,
        }
    }
}

impl From<VSEvent> for InputBehavior {
    fn from(value: VSEvent) -> Self {
        match value {
            VSEvent::ControlPressed => Self::ControlPressed,
            VSEvent::ControlReleased => Self::ControlReleased,
            VSEvent::TypingDetected => Self::TypingDetected,
            VSEvent::TypingKeyLetters => Self::TypingKeyLetters,
            VSEvent::TypingKeyNumbers => Self::TypingKeyNumbers,
            VSEvent::TypingKeySpace => Self::TypingKeySpace,
            VSEvent::TypingKeyDelete => Self::TypingKeyDelete,
            VSEvent::TypingKeyReturnKey => Self::TypingKeyReturnKey,
            VSEvent::ManualSwitchDetected => Self::ManualSwitchDetected,
            VSEvent::CooldownExpired => Self::CooldownExpired,
        }
    }
}

impl From<EngineAction> for VSAction {
    fn from(value: EngineAction) -> Self {
        match value {
            EngineAction::SwitchToPrimary => Self::SwitchToPrimary,
            EngineAction::SwitchToVoice => Self::SwitchToVoice,
            EngineAction::EnterCooldown => Self::EnterCooldown,
            EngineAction::NoOp => Self::NoOp,
        }
    }
}

impl From<EngineTimer> for VSTimer {
    fn from(value: EngineTimer) -> Self {
        Self {
            has_value: true,
            kind: value.kind.into(),
            delay_seconds: value.delay_seconds,
        }
    }
}

impl From<EngineTimerKind> for VSTimerKind {
    fn from(value: EngineTimerKind) -> Self {
        match value {
            EngineTimerKind::VoiceActivationDelay => Self::VoiceActivationDelay,
            EngineTimerKind::PrimaryReturnDelay => Self::PrimaryReturnDelay,
            EngineTimerKind::Cooldown => Self::Cooldown,
        }
    }
}
