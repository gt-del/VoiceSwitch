# Permission And Platform Regression Checklist

## Scenario Summary

- 变更目标：修复登录启动 / 重启后主窗口未创建时，`VoiceSwitchAppModel.load()` 不执行的问题；把触发键改为 `Fn` 双击；并收口 `/Applications/VoiceSwitch.app` 的手动启动与权限身份诊断。
- 相关链路：Launch at Login、监听初始化、`Fn` 触发、权限 degrade / recover path、手动启动主窗口、ad hoc 重签后的身份失配提示。

## Checklist

- [ ] First launch without required permission
  期望：应用启动后立即显示权限阻塞原因；即使主窗口尚未手动打开，菜单栏状态也已反映不可用。
- [ ] Manual launch from `/Applications/VoiceSwitch.app`
  期望：手动从 `/Applications` 打开后会直接出现真实主窗口，而不是只存在菜单栏进程。
- [ ] Permission granted after guidance
  期望：授予 Accessibility / Input Monitoring 后重新激活应用，监听会自动恢复，不要求先打开主窗口。
- [ ] Permission re-granted after replacing local build
  期望：若覆盖安装过本地构建，阻塞原因优先提示“授权对象疑似失配”；提示文案明确要求只从 `/Applications/VoiceSwitch.app` 启动并重新勾选该对象。
- [ ] Permission denied and app degrades safely
  期望：登录启动后若权限仍缺失，不崩溃、不误报为运行中，日志保留 `stopped_due_to_blocking_issue` 证据。
- [ ] Permission revoked while app is running
  期望：监听停止，状态切为不可用；重新授予后可通过 app activation 自动恢复。
- [ ] Event Tap fails during initialization
  期望：登录启动或手动启动时若 Event Tap 创建失败，状态显示“监听未运行”，日志可见失败原因。
- [ ] Fn double-tap toggles exactly once
  期望：单独的 `Fn` 连续两次按下并释放后，只产生一次 toggle；单击 `Fn` 不触发。
- [ ] Duplicate Fn `flagsChanged` notifications do not cancel the toggle
  期望：同一次 `Fn` 物理按下 / 释放即使出现多条重复 `flagsChanged`，双击判定仍然只触发一次，不会被误取消。
- [ ] Synthetic Fn `keyDown` notifications do not cancel the toggle
  期望：某些机器在 `Fn` 释放后追加的 `keyDown keyCode=179` 不会被误当成夹入其他键，双击判定仍能完成。
- [ ] Fn double-tap is cancelled by intervening input
  期望：两次 `Fn` 之间夹入任意其他键或修饰键，会取消本轮双击触发。
- [ ] Event Tap is invalidated and recovered
  期望：`tapDisabled` 后可以重试恢复；恢复后状态重新变为运行中。
- [ ] Target input source is unavailable
  期望：即使启动初始化已提前，失效输入法仍会在 `load()` 中被识别并阻塞自动化，不误启动监听。
- [ ] Launch at Login enable / disable behavior is correct
  期望：开启登录启动后，重启登录会在无主窗口场景下完成初始化；关闭后不再自动拉起。
- [ ] Degrade path evidence is logged
  期望：至少能看到权限阻塞、监听停止、启动项状态不一致等诊断日志。
- [ ] Recover path evidence is logged
  期望：至少能看到 `permissions_recovered`、`restarted` 等恢复证据。

## Blocking Risks

- 若后续再次把 `load()` 挂回某个窗口生命周期，登录启动无窗口场景会重新失效。
- 若未来又把触发键说明写回左 `Control`，用户会按旧规则操作，导致排障信息和真实行为再次偏离。
- 若未来新增第二个 app 入口或辅助启动器，必须复用同一启动初始化工厂，不能各自拼装一套模型。
- ad hoc 本地构建仍不具备正式 Developer ID 的稳定授权身份；当前规则只能更早识别并提示失配风险，不能从根本上替代正式签名。

## Notes

- 本次修复通过 app 级模型工厂在启动时立即执行 `load()`，并移除了主窗口里的延后加载。
- `Fn` 双击仍映射到现有 core toggle 入口，Rust / FFI 事件名暂未改名。
- 当前自动化验证已覆盖“创建模型即加载并启动监听判断”“`Fn` 双击触发”“重复 `Fn` 状态通知不误取消双击”“合成 `Fn keyDown` 不误取消双击”和“运行身份失配诊断”的单测，并会在安装包替换后继续做手动启动验证。
