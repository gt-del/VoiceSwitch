#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InputBehavior {
    OptionPressed,
    OptionReleased,
    TypingDetected,
    ManualSwitchDetected,
    CooldownExpired,
}
