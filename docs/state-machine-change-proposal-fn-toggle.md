# State Machine Change Proposal

## Background

用户要求把当前“左 `Control` 双击切换输入法”改为“`Fn` 双击切换输入法”，并完全替代左 `Control`。同时当前开发安装链路会持续生成 ad hoc 新身份，导致重新授权后仍可能命中旧的 TCC 授权对象。

## Current Behavior

- Swift 监听层使用 `flagsChanged + keyCode 59` 识别左 `Control` 按下 / 释放。
- `leftControlTapCompleted` 会映射为 `InputBehavior.controlPressed`，驱动 Rust core 进行 toggle。
- README、设置页、菜单栏和概览文案全部以左 `Control` 为主语义。
- 安装产物采用 ad hoc 签名覆盖 `/Applications/VoiceSwitch.app`，权限授权对象容易随构建变化。

## Proposed Change

- 平台层把触发键改为“单独的 `Fn` 两次按下并释放，中间不能夹其他键”。
- 左 `Control` 监听和相关 UI 文案全部移除，不保留双支持。
- Rust core 状态机不新增状态，也不修改 toggle 语义；平台层继续把触发完成事件映射到现有 toggle 入口。
- 日志和原始事件描述改为 `Fn` 语义，避免排障信息继续误导为左 `Control`。
- 安装链路改为固定 `/Applications/VoiceSwitch.app` 目标，并停止用“每次都变的构建身份”当作长期授权对象。

## Affected Semantics

- States:
  - 无新增状态，继续使用 `idlePrimary` / `voiceMode` / `cooldown`
- Events:
  - Rust core 入口事件保持现有 toggle 入口不变
  - Swift 平台事件从左 `Control` tap 完成改为 `Fn` tap 完成
- Transitions:
  - 无变化，仍为第一次 toggle 切到语音，第二次 toggle 切回普通
- Scores / Thresholds:
  - 无变化
- Cooldown:
  - 无变化

## Affected Log Fields

- 不改 schema
- `raw_event` 和监听层诊断改为 `Fn` 语义
- 如保留 core `trigger=controlPressed`，需在文档中明确它代表“toggle 入口”而非物理左 `Control`

## Affected Settings

- 无新增设置项
- 设置页说明文案改为 `Fn` 双击语义

## Compatibility

- Rust / C FFI 边界保持不变，避免再次引入权限 / 安装问题之外的 ABI 漂移
- 旧的左 `Control` 触发行为移除，不保留兼容

## Observability Changes

- README、设置页、菜单栏、概览文案统一为 `Fn` 双击
- 监听原始事件描述改为 `Fn`，便于排查

## Test Impact

- 键盘监听测试需要改为覆盖 `Fn` 双击完成、其他键打断、单击不触发
- AppModel 测试保持 toggle 行为不变，但输入来源改为 `Fn` 完成事件
- 安装 / 启动路径需要补充“手动启动显示主窗口”和“稳定权限身份”验证

## FFI Review Required

- No
- Why:
  - 本次建议不修改 Rust / C FFI 枚举与错误码，仅在 Swift 平台监听层改变物理按键来源
