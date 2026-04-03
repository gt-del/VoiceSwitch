#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EngineState {
    IdlePrimary,
    OptionPending,
    VoiceActive,
    Cooldown,
}
