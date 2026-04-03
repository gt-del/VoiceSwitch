#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EngineAction {
    SwitchToPrimary,
    SwitchToVoice,
    EnterCooldown,
    NoOp,
}
