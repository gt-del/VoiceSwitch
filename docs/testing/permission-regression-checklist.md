# Permission And Platform Regression Checklist

## Scenario Summary

本清单用于覆盖 VoiceSwitch 在 macOS 上与权限、全局键盘监听、输入源可用性和恢复链路相关的回归项。当前版本需要重点确认以下事实：

- 主窗口和设置页都能区分：
  - `AccessibilityDenied`
  - `InputMonitoringDenied`
  - `RuntimeIdentityMismatch`
  - `KeyboardMonitoringStopped`
- 主窗口默认不直接展示完整本机路径，完整路径改为通过导出日志获取
- UI 能区分“系统未授权”和“当前运行目标未命中已授权条目”
- `.app` 形态是权限验证和实机回归的主路径，`swift run` 只用于开发调试

## Checklist

- [ ] First launch without required permission
  - 预期：主窗口显示 `不可用`
  - 预期：`AXIsProcessTrusted=false`
  - 预期：`CGPreflightListenEventAccess=false`
  - 预期：阻塞原因明确指出是系统未授予辅助功能权限或输入监听权限

- [ ] Permission granted after guidance
  - 预期：在系统设置授予权限后，切回 VoiceSwitch
  - 预期：应用自动刷新权限并自动尝试恢复监听
  - 预期：大多数情况下无需手动点击 `重试监听`
  - 预期：菜单栏状态与主窗口一致

- [ ] Permission denied and app degrades safely
  - 预期：不会启动全局监听
  - 预期：按下 `Option` 不会自动切换输入法
  - 预期：日志记录 `accessibility_denied` 或 `input_monitoring_denied`

- [ ] Permission revoked while app is running
  - 预期：监听失效后 UI 变为 `不可用`
  - 预期：阻塞原因更新为当前实际权限问题
  - 预期：日志能看到 degrade path 证据

- [ ] Event Tap fails during initialization
  - 预期：主窗口显示监听未运行
  - 预期：菜单栏状态不误报为正常
  - 预期：若自动恢复失败，可以通过 `重试监听` 触发恢复

- [ ] Event Tap is invalidated and recovered
  - 预期：监听失效后记录恢复日志
  - 预期：恢复成功后状态重新变为可运行
  - 预期：恢复后按住 / 松开 `Option` 行为正确

- [ ] Target input source is unavailable
  - 预期：Primary / Voice IME 缺失或相同会直接阻塞运行
  - 预期：错误提示显示在主窗口，不依赖日志
  - 预期：非法配置不会写入持久层

- [ ] Launch at Login enable / disable behavior is correct
  - 预期：设置页切换后自动保存
  - 预期：系统要求额外批准时，UI 给出明确提示

- [ ] Degrade path evidence is logged
  - 预期：日志包含权限拒绝、监听停止、阻塞原因等结构化证据

- [ ] Recover path evidence is logged
  - 预期：日志包含 `restarted`、`running` 或权限恢复后的重试结果

- [ ] Runtime identity mismatch can be explained
  - 预期：README 可以解释为什么 `swift run` / Xcode / 固定 `.app` 会出现不同授权对象
  - 预期：UI 能提示下一步应该重新绑定哪个运行目标

- [ ] Log export keeps full diagnostics
  - 预期：默认界面只展示遮盖后的路径
  - 预期：导出日志包含完整运行路径、Bundle ID 和 Bundle 路径

## Blocking Risks

- `.build` 可执行文件与 `.app` Bundle 不是同一个授权对象，容易造成“系统里看起来已勾选，但当前进程仍不受信任”
- Input Monitoring 与 Accessibility 在 macOS 中是两条独立权限链路，不能再合并成单一状态
- 关闭主窗口后应用继续常驻，恢复链路必须能在无主窗口场景下通过菜单栏继续触发

## Notes

- 实机回归优先使用 `.app`：`./scripts/run-dev-app.sh`
- 需要重点记录以下实际值：
  - `AXIsProcessTrusted`
  - `CGPreflightListenEventAccess`
  - 当前运行路径
  - 当前 Bundle ID
  - 当前 Bundle 路径
  - 当前阻塞原因 kind
