# 显卡开关

适用于支持双显卡切换的 Intel Mac 的原生菜单栏工具。无第三方依赖，无 Dock 图标。

应用图标为「芯片 + 青绿色拨杆」，源图位于 `Resources/AppIcon.png`，生成提示词位于 `Resources/AppIcon.prompt.txt`。构建时自动生成包含普通与 Retina 尺寸的 ICNS。菜单栏使用同造型的单色矢量绘图，随系统深浅外观适配。

## 构建与运行

```sh
bash scripts/build.sh
open build/显卡开关.app
```

也可以在 Finder 中双击 `build/显卡开关.app`，或拖入「应用程序」。登录自动启动可在 macOS「系统设置 → 通用 → 登录项」中自行添加应用。

点击菜单栏的芯片图标，选择模式：

「按电源切换：插电独显 / 电池集显」会一次设置电源适配器使用独显、电池使用集显：

```sh
sudo pmset -b gpuswitch 0 -c gpuswitch 1
```

由 macOS 在电源变化时应用相应配置，无需应用后台轮询执行命令，也无需在每次插拔时重新授权。退出应用或重启后配置仍保留。菜单会勾选此策略，菜单栏文字随当前电源显示「独 / 集」。

手动选择以下任意一项，会统一所有电源模式并覆盖上述策略。再次选择「按电源切换」即可恢复：

| 模式 | 命令 |
| --- | --- |
| 集成显卡 | `sudo pmset -a gpuswitch 0` |
| 独立显卡 | `sudo pmset -a gpuswitch 1` |
| 自动切换 | `sudo pmset -a gpuswitch 2` |

注意 `0` 是集显，`2` 是自动。参考 [gpuswitch-cli 作者文档](https://kud.io/projects/gpuswitch-cli/docs/modes)。

切换时通过 AppleScript 的 `with administrator privileges` 触发 macOS 管理员授权。应用不保存密码、不修改 sudoers、不安装常驻 root 服务。取消授权不会主动修改设置。切换成功后重新读取所有电源配置核验。

菜单栏「集 / 独 / 自」表示当前电源配置中的策略，不是实时 GPU 使用率或所有应用的实际渲染设备。状态每 10 秒、打开菜单及唤醒时刷新。配置通过 `pmset -g custom` 读取，当前电源通过 `pmset -g batt` 识别；配置读取失败时禁止切换。

`-a` 应用于所有电源配置；配置会在退出应用或重启后保留。恢复系统自动调度请选择「自动切换」。外接显示器或部分应用可能需要独显，实际切换受硬件与系统限制。

## 验证

```sh
bash scripts/test.sh
```

自动验证电源配置解析、数值映射、命令白名单、按电源策略识别、手动覆盖识别，以及本机只读配置查询。管理员授权、取消和实际插拔电源切换需在交互式桌面上验证。
