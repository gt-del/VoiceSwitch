# State Machine Change Proposal

## Background

当前版本用 `Option` 作为切到 `Voice IME` 的触发键。豆包输入法本身也使用 `Option` 作为按住说话键，导致 VoiceSwitch 先消费了切换时机，豆包拿不到自己的启动边沿。后续改成“按住左 `Control` 保持切换”后，又会把豆包实际收到的快捷键变成 `Control+Option`，仍然无法满足豆包对裸 `Option` 的要求。

## Current Behavior

- 用户按下 `Option`
- 平台层把该事件映射为 `optionPressed`
- 状态机从 `idlePrimary` 进入 `voiceHeld`
- Swift 层执行 `switchToVoice`
- 用户松开 `Option`
- 平台层映射为 `optionReleased`
- 状态机回到 `idlePrimary`

## Proposed Change

- 用户第一次轻按左 `Control`
- 平台层仍映射到既有内部事件 `optionPressed`
- 状态机、FFI、Rust 语义保持不变
- Swift UI 和 README 改为“左 `Control` toggle 切换”
- 左 `Control` 松开不触发切回
- 用户第二次轻按左 `Control` 时，Swift 编排层把该次触发解释为内部 `optionReleased`
- `Option` 不再被 VoiceSwitch 当作切换触发键，可留给豆包输入法自身使用

## Affected Semantics

- States:
  - 无变化
- Events:
  - 抽象事件无变化
  - 平台层从“`Option` 触发”改为“左 `Control` 第一次按下进入、第二次按下退出”
- Transitions:
  - Rust 侧转移无变化
  - Swift 平台编排从“按下进入、松开退出”改为“第一次按下进入、第二次按下退出”
- Scores / Thresholds:
  - 无变化
- Cooldown:
  - 无变化

## Affected Log Fields

- 结构化 `trigger` 保持现状，仍为 `optionPressed / optionReleased`
- 原始键盘事件描述改为 `controlDown / controlUp`
- 用户可见提示文案从 `Option` 改为左 `Control`

## Affected Settings

- 无新增设置
- 现有行为说明文案需要同步

## Compatibility

- 已保存配置不受影响
- Rust core、FFI、自动保存机制不受影响
- 用户操作习惯从按住 `Option` 改为轻按左 `Control` 进入，再按一次退出

## Observability Changes

- 诊断区与日志导出的原始事件描述更准确反映真实触发键
- 结构化 trigger 暂不重命名，避免扩大边界影响

## Test Impact

- 平台层按键映射测试需改为左 `Control`
- 增加“右 `Control` 忽略”测试
- 键盘事件链路测试需改为 `controlDown(keyCode:59)`

## FFI Review Required

- No
- Why:
  - 这次只改 macOS 平台层键位映射与用户可见文案，不改 Rust 事件枚举和 FFI 形状
