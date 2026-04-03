---
name: macos-permission-test-checklist
description: Use when VoiceSwitch changes permissions, Event Tap, input sources, launch-at-login, or listener initialization and recovery paths on macOS and regression coverage is required.
---

# macOS Permission Test Checklist

涉及权限、监听、输入源或恢复链路时，必须补一份回归检查清单。

## 何时触发

- Accessibility / Input Monitoring 权限相关改动
- Event Tap 初始化、失效、恢复链路改动
- 输入源可用性或切换链路改动
- Launch at Login 改动
- 监听初始化或监听恢复路径改动
- 权限缺失时的 UI 引导改动

## 输入工件

- 相关平台改动说明
- 当前 degrade path / recover path 设计
- 相关 UI 引导和日志字段

## 固定步骤

1. 覆盖首次授权、拒绝、撤销、恢复四类核心路径。
2. 覆盖监听初始化失败和监听失效后的恢复路径。
3. 覆盖目标输入源不可用或失效场景。
4. 覆盖 Launch at Login 开关与恢复后的行为。
5. 检查每条路径的日志和诊断证据是否足够。

## 输出工件

- 使用 [permission-regression-checklist.md](/Users/didi/Code/github/VoiceSwitch/.codex/skills/macos-permission-test-checklist/templates/permission-regression-checklist.md)

## 验收标准

- 授权、拒绝、撤销、恢复路径都可检查
- degrade path / recover path 都有验证项
- 输入源失效和启动项行为都有明确检查项
