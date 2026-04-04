# VoiceSwitch 工程设计文档

## 1. 项目概述

### 1.1 项目目标

VoiceSwitch 是一个运行于 macOS 的菜单栏常驻工具，用于根据用户输入行为在“常规输入法”和“语音输入法”之间自动切换。

本项目的核心目标不是做一个按应用切换输入法的工具，而是做一个按“输入行为模式”切换输入法的工具：

- 用户平时键盘输入时，系统保持在用户配置的常规输入法。
- 用户触发语音输入行为时，系统切换到用户配置的语音输入法。
- 用户恢复正常打字后，系统自动切回常规输入法。
- 用户始终保留手动切换输入法的最高优先级。

### 1.2 非目标

以下内容不属于第一阶段目标：

- 不做基于网站域名的输入法切换。
- 不做复杂的按应用规则系统。
- 不做云同步。
- 不做跨平台版本。
- 不做自动识别任意语音软件的通用框架。
- 不做输入法内容层面的文本处理。

### 1.3 一期适用场景

一期默认针对如下场景优化：

- 常规输入法：由用户自定义，例如鼠须管、ABC、日语输入法。
- 语音输入法：由用户自定义，例如豆包语音输入法。
- 语音触发行为：目前以按住 `Option` 作为主要信号。
- 打字行为：以字母、数字、标点、空格、删除、回车等键盘行为作为恢复常规输入法的核心依据。

------

## 2. 产品需求落地为工程需求

## 2.1 核心需求

### FR-1 输入法角色配置

系统必须支持用户配置两个输入法角色：

- Primary IME：常规输入法
- Voice IME：语音输入法

约束：

- 两者必须从系统当前可用输入源中选择。
- 配置保存到本地。
- 若配置的输入法失效、卸载或不可用，系统应标记配置异常并回退为禁用自动切换。

### FR-2 默认偏向常规输入法

当没有检测到语音行为时，系统应保持或恢复到常规输入法。

### FR-3 语音触发检测

当用户按下 `Option`，并在短时间窗口中未表现出明显键盘打字行为时，系统判定进入语音模式候选。

### FR-4 自动切换到语音输入法

当语音模式候选满足判定条件时，系统自动切换到 Voice IME。

### FR-5 自动恢复到常规输入法

当检测到用户恢复正常键盘打字行为时，系统自动切换回 Primary IME。

### FR-6 手动切换优先

若系统检测到用户手动切换输入法，则在 cooldown 时间窗内停止自动切换。

### FR-7 菜单栏交互

必须提供菜单栏入口，用于：

- 查看当前状态
- 开关自动切换
- 显示当前输入法配置
- 打开设置页
- 查看调试日志
- 临时暂停自动切换

### FR-8 开机启动

支持配置开机自动启动。

### FR-9 调试能力

必须提供可视化调试日志，便于用户识别误切问题。

------

## 2.2 非功能需求

### NFR-1 响应性

- 从判定需要切换到实际完成输入法切换的目标延迟：< 300ms。
- 菜单栏状态刷新不得阻塞主线程。

### NFR-2 稳定性

- 工具异常退出不得影响系统输入法本身。
- 没有权限时应降级而不是崩溃。
- Event Tap 失效后应自动尝试恢复。

### NFR-3 可观测性

- 所有关键状态变更都必须记录日志。
- 关键判定必须具备“原因说明”。

### NFR-4 可调优

- 所有阈值必须可配置，但提供合理默认值。
- 状态机和判定逻辑必须与 UI 层解耦，便于后续调参。

### NFR-5 可扩展性

架构设计要允许未来扩展以下能力：

- 自定义触发键
- App 黑名单
- 按应用覆盖策略
- 多语音输入法支持
- 更多输入行为特征

------

## 3. 整体架构设计

采用分层架构 + 事件驱动模型。

```text
┌────────────────────────────┐
│ MenuBar UI / Settings UI   │
└────────────┬───────────────┘
             │
┌────────────▼───────────────┐
│ Application Coordinator    │
│ (生命周期与依赖装配)        │
└────────────┬───────────────┘
             │
┌────────────▼────────────────────────────────────┐
│ Core Domain                                     │
│ - StateMachine                                  │
│ - RuleEngine                                    │
│ - BehaviorClassifier                            │
│ - InputModeOrchestrator                         │
└────────────┬────────────────────────────────────┘
             │
┌────────────▼────────────────────────────────────┐
│ Infrastructure                                  │
│ - KeyboardEventTapService                       │
│ - InputSourceService                            │
│ - ManualSwitchDetector                          │
│ - ForegroundAppService(可选扩展)                │
│ - LaunchAtLoginService                          │
│ - SettingsStore                                 │
│ - Logger                                        │
└─────────────────────────────────────────────────┘
```

### 3.1 架构原则

1. **判定逻辑与系统 API 解耦**
   - Core Domain 不直接依赖 macOS API。
   - 系统事件由 Infrastructure 转换为领域事件。
2. **单向数据流**
   - 系统事件 → 领域事件 → 状态机 → 动作决策 → 执行动作 → UI 刷新/日志。
   - 时间窗调度由 Rust 状态机输出 timer 决策，Swift 只负责执行。
3. **主线程最小化**
   - 键盘事件监听和规则判断在专用队列处理。
   - UI 仅订阅状态快照。
4. **所有自动切换可解释**
   - 每一次切换必须有 trigger、reason、source state、target state。
   - Rust core 负责产出业务语义字段，Swift 执行层只补充 current input source、target input source、cooldown status。

------

## 4. 核心领域模型

## 4.1 输入法角色模型

```text
IMEProfile
- id: String                       // 系统输入源 ID
- displayName: String              // 显示名称
- role: IMERole                    // primary / voice
- isAvailable: Bool
IMERole
- primary
- voice
```

## 4.2 键盘事件领域模型

```text
KeyEvent
- timestamp: TimeInterval
- keyCode: CGKeyCode
- eventType: keyDown / keyUp / flagsChanged
- modifiers: ModifierFlags
- source: hardware / system / unknown
```

说明：

- `flagsChanged` 用于识别 modifier 键状态变化。
- `Option` 的 down/up 主要依赖 flagsChanged 判定。

## 4.3 输入行为分类

```text
InputBehavior
- optionPressed
- optionReleased
- typingCandidate
- typingConfirmed
- voiceCandidate
- idle
- unsupported
```

## 4.4 系统状态模型

```text
EngineState
- disabled
- idlePrimary
- optionPending
- voiceActive
- typingActive
- cooldown
- error
```

### 状态解释

- `disabled`：自动切换关闭。
- `idlePrimary`：常规待机态，偏向 Primary IME。
- `optionPending`：检测到 Option 被按下，等待进一步判定。
- `voiceActive`：当前认为用户处于语音输入场景，应使用 Voice IME。
- `typingActive`：当前检测到用户进行常规打字，应使用 Primary IME。
- `cooldown`：检测到用户手动干预，暂时不自动切换。
- `error`：关键服务故障或配置失效。

## 4.5 动作模型

```text
EngineAction
- switchToPrimary(reason)
- switchToVoice(reason)
- enterCooldown(reason, until)
- clearCooldown(reason)
- noOp(reason)
- emitWarning(reason)
```

------

## 5. 状态机设计

## 5.1 状态转移总览

```text
disabled
  -> enable -> idlePrimary

idlePrimary
  -> optionPressed -> optionPending
  -> manualSwitchDetected -> cooldown

optionPending
  -> typingConfirmed -> typingActive
  -> optionWindowExpired + noTyping -> voiceActive
  -> optionReleased + noVoiceEvidence -> idlePrimary
  -> manualSwitchDetected -> cooldown

voiceActive
  -> typingConfirmed -> typingActive
  -> optionReleased + silenceTimeout -> idlePrimary
  -> manualSwitchDetected -> cooldown

typingActive
  -> inactivityShortTimeout -> idlePrimary
  -> optionPressed -> optionPending
  -> manualSwitchDetected -> cooldown

cooldown
  -> cooldownExpired -> idlePrimary
  -> disable -> disabled

error
  -> recover -> idlePrimary / disabled
```

## 5.2 核心状态判定细则

### 5.2.1 idlePrimary

进入条件：

- 应用启动后初始化完成
- typingActive 超时回落
- cooldown 结束
- voiceActive 退出

动作：

- 确保当前目标输入法为 Primary IME
- 清空短期按键缓冲区
- 清空 voice candidate 标记

### 5.2.2 optionPending

进入条件：

- 检测到 Option key down

内部上下文：

- `optionPressedAt`
- `keysObservedDuringOptionWindow`
- `typingSignalsDuringWindow`

默认等待窗口：

- 150ms ~ 250ms，默认建议 180ms
- 一期设置页先开放 `0.05s ~ 1.0s`

在该窗口内：

- 若捕获到明显 typing 信号，则进入 `typingActive`
- 若窗口结束仍无 typingConfirmed，则进入 `voiceActive`

### 5.2.3 voiceActive

进入条件：

- optionPending 到达阈值且无明显 typing 行为

动作：

- 切换到 Voice IME
- 记录进入原因
- 启动 voice 活跃监测计时器

退出条件：

- 检测到 typingConfirmed
- optionReleased 后，达到 voiceExitDelay 且未再观察到 voice 相关行为

建议默认值：

- `voiceExitDelay = 800ms`
- 一期设置页先开放 `0.0s ~ 5.0s`

### 5.2.4 typingActive

进入条件：

- 检测到连续键盘输入行为
- voiceActive 中检测到 typingConfirmed
- optionPending 中提前检测到 typingConfirmed

动作：

- 切换到 Primary IME
- 刷新 typingLastSeenAt

退出条件：

- 一段较短的 inactivity 时间后回到 idlePrimary

建议默认值：

- `typingDecayInterval = 800ms`

### 5.2.5 cooldown

进入条件：

- 检测到用户手动切换输入法

动作：

- 停止所有自动切换动作
- 记录 `cooldownUntil`

建议默认值：

- `cooldownDuration = 5s`
- 一期设置页先开放 `0.5s ~ 30.0s`

## 5.2.6 一期可调参数

一期先开放以下可调参数，不引入复杂评分模型：

- `optionPendingWindow`
- `cooldownDuration`
- `voiceExitDelay`

要求：

- 参数定义在 Rust core，Swift 只负责传递和持久化配置。
- 设置页改动后对新事件立即生效，点击 Save 后持久化。
- 参数必须有默认值与合法范围校验。

## 5.2.7 一期日志字段

一期日志至少稳定输出以下字段：

- `trigger`
- `reason`
- `source_state`
- `target_state`
- `action`
- `current_input_source`
- `target_input_source`
- `cooldown_status`

------

## 6. 行为分类器设计

行为分类器是整个项目的核心。其职责是把底层零散键盘事件转换成高层行为判断。

## 6.1 输入

- 原始键盘事件流
- 当前状态机状态
- 时间窗口缓存
- 配置阈值

## 6.2 输出

- `typingCandidate`
- `typingConfirmed`
- `voiceCandidate`
- `optionPressed`
- `optionReleased`

一期最小实现中：

- 平台层先把原始键盘事件映射为稳定键类别，例如 `letters`、`numbers`、`space`、`delete`、`returnKey`
- Rust core 再按 `typingKeyWhitelist` 决定这些键类别是否构成 typing 行为

## 6.3 按键分类表

建议建立一个 Key Semantic Layer，把 keyCode 分为以下几类：

### 6.3.1 强 typing 键

这些键一旦连续出现，应高概率判定为打字：

- A-Z
- 0-9
- 常用标点
- Space
- Return
- Delete
- Tab（可配置是否视为 typing）

### 6.3.2 弱 typing 键

可能是打字，也可能是编辑行为：

- Left / Right / Up / Down
- Home / End
- PageUp / PageDown

默认不作为 typingConfirmed 的主依据，但可累计分数。

### 6.3.3 modifier 键

- Option
- Shift
- Control
- Command
- Fn / Globe

### 6.3.4 忽略键

可配置忽略：

- 音量
- 亮度
- 媒体键
- 截图快捷键所带来的非文本输入行为

## 6.4 判定算法（推荐实现）

采用“短窗口评分模型”，而不是单一 if-else。

### 6.4.1 Typing Score

为最近 N ms 内的按键事件计算 typingScore：

示例规则：

- 强 typing 键 keyDown：+3
- 连续两个不同强 typing 键在 250ms 内：额外 +2
- Space / Delete / Return：+2
- 弱 typing 键：+1
- 单独 modifier：0
- Option 按下本身：0

判定阈值：

- `typingCandidateThreshold = 3`
- `typingConfirmedThreshold = 5`

### 6.4.2 Voice Score

语音模式不做复杂评分，优先采用“Option + 无 typing”策略：

- Option down 后开启窗口
- 在窗口内若 typingScore < threshold，则判定 voiceCandidate
- 窗口到期后进入 voiceActive

原因：

- 语音是缺省行为，不应强依赖更多系统信号。
