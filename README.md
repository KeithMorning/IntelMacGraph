<p align="center">
  <img src="Resources/AppIcon.png" alt="GPU Switch icon: a graphics chip with a toggle" width="180">
</p>

<h1 align="center">GPU Switch · 显卡开关</h1>
<p align="center"><a href="#english">English</a> · <a href="#简体中文">简体中文</a></p>

<a id="english"></a>

## English

A lightweight native menu bar app for switching graphics modes on dual-GPU Intel Macs. The app interface follows your macOS language and is available in English and Simplified Chinese.

### Features

- Shows the configured GPU policy for the current power source in the menu bar.
- Uses the discrete GPU on AC power and the integrated GPU on battery with **Switch by Power Source**.
- Offers manual Integrated, Discrete, and Automatic modes.
- Applies changes through the macOS administrator prompt. The app never stores your password or installs a privileged background service.
- Includes a custom macOS app icon and a matching monochrome menu bar icon.

### GPU modes

| Mode | `pmset` value | Behavior |
| --- | ---: | --- |
| Integrated | `0` | Force the integrated GPU. |
| Discrete | `1` | Force the discrete GPU. |
| Automatic | `2` | Let macOS switch GPUs dynamically. |

See the [GPU mode reference](https://kud.io/projects/gpuswitch-cli/docs/modes) for more detail.

#### Switch by power source

Choose **Switch by Power Source: Discrete on AC / Integrated on Battery** in the menu. It configures both power profiles:

```sh
sudo pmset -b gpuswitch 0 -c gpuswitch 1
```

macOS applies the corresponding profile when you connect or disconnect the power adapter. The setting persists after you quit the app or restart your Mac. Choose a manual mode to apply it to both profiles; choose **Switch by Power Source** again to restore different modes for AC and battery.

#### Manual modes

Choose a mode from the menu, or run the matching command in Terminal:

```sh
sudo pmset -a gpuswitch 0  # Integrated
sudo pmset -a gpuswitch 1  # Discrete
sudo pmset -a gpuswitch 2  # Automatic
```

`-a` applies the selected mode to all power profiles. Settings persist until changed. Some apps may need to be restarted to use the selected GPU. External displays and hardware can also affect switching behavior.

### Download

[Download GPU Switch 1.2.0 for Intel Mac](https://github.com/KeithMorning/IntelMacGraph/releases/download/v1.2.0/GPU-Switch-v1.2.0-macOS-Intel.zip) · [SHA-256 checksums](https://github.com/KeithMorning/IntelMacGraph/releases/download/v1.2.0/SHA256SUMS.txt) · [GitHub Releases](https://github.com/KeithMorning/IntelMacGraph/releases)

The ZIP contains the macOS app. To build it yourself, use macOS 12 or later with an Intel Mac and the Xcode Command Line Tools:

```sh
bash scripts/build.sh
open "build/显卡开关.app"
```

You can also open the app in Finder, or add it to **System Settings → General → Login Items** to launch it at login. Select a mode and approve the macOS administrator prompt to apply GPU settings.

### Status and limitations

The menu bar shows the configured policy for the current power source, not GPU utilization or the renderer used by every app. Status refreshes every 10 seconds, when the menu opens, and after the Mac wakes from sleep.

The app reads `pmset -g custom` and `pmset -g batt`. If it cannot read the current configuration, mode selection is disabled. GPU switching depends on the Mac model, macOS, external displays, and running apps.

### Verify

```sh
bash scripts/test.sh
```

Checks cover power-profile parsing, mode values, power-source policy detection, manual overrides, and read-only inspection of the current Mac's settings. Applying a mode requires the interactive macOS administrator prompt.

<a id="简体中文"></a>

## 简体中文

「显卡开关」是一款适用于支持双显卡切换的 Intel Mac 的轻量原生菜单栏应用。应用界面会跟随 macOS 语言，支持简体中文和英文。

### 功能

- 在菜单栏显示当前电源配置对应的显卡策略。
- 选择**按电源切换**后，接入电源使用独显，电池供电时使用集显。
- 支持手动设置集显、独显和自动切换。
- 通过 macOS 管理员授权应用设置，不保存密码，也不安装 root 常驻服务。
- 自定义 macOS 应用图标和配套的菜单栏单色图标。

### 显卡模式

| 模式 | `pmset` 值 | 说明 |
| --- | ---: | --- |
| 集成显卡 | `0` | 强制使用集显。 |
| 独立显卡 | `1` | 强制使用独显。 |
| 自动切换 | `2` | 由 macOS 根据需要动态切换。 |

详细说明见 [GPU 模式参考文档](https://kud.io/projects/gpuswitch-cli/docs/modes)。

#### 按电源切换

在菜单中选择**按电源切换：插电独显 / 电池集显**，一次性设置两种电源配置：

```sh
sudo pmset -b gpuswitch 0 -c gpuswitch 1
```

macOS 会在插拔电源时自动应用对应配置。退出应用或重启后设置仍然有效。手动选择模式会覆盖电池和电源两种配置；再次选择**按电源切换**即可恢复。

#### 手动模式

在菜单中选择模式，也可以在终端运行对应命令：

```sh
sudo pmset -a gpuswitch 0  # 集成显卡
sudo pmset -a gpuswitch 1  # 独立显卡
sudo pmset -a gpuswitch 2  # 自动切换
```

`-a` 会将所选模式应用于所有电源配置。设置会一直保留，直到再次修改。部分应用可能需要重启后才会使用新选定的显卡。外接显示器和硬件也可能影响切换行为。

### 下载

[下载 Intel Mac 版显卡开关 1.2.0](https://github.com/KeithMorning/IntelMacGraph/releases/download/v1.2.0/GPU-Switch-v1.2.0-macOS-Intel.zip) · [SHA-256 校验和](https://github.com/KeithMorning/IntelMacGraph/releases/download/v1.2.0/SHA256SUMS.txt) · [GitHub Releases](https://github.com/KeithMorning/IntelMacGraph/releases)

ZIP 文件中包含 macOS 应用。也可以在 macOS 12 或更高版本的 Intel Mac 上使用 Xcode Command Line Tools 自行构建：

```sh
bash scripts/build.sh
open "build/显卡开关.app"
```

也可以在 Finder 中打开应用，或将它加入**系统设置 → 通用 → 登录项**以便登录后自动启动。选择显卡模式并通过 macOS 管理员授权后即可应用设置。

### 状态与限制

菜单栏显示当前电源配置中的显卡策略，不代表 GPU 使用率或每个应用实际使用的渲染设备。状态每 10 秒、打开菜单和 Mac 从睡眠唤醒后刷新。

应用通过 `pmset -g custom` 和 `pmset -g batt` 读取设置。如果无法读取当前配置，会禁用模式选择。显卡切换效果取决于 Mac 机型、macOS、外接显示器和运行中的应用。

### 验证

```sh
bash scripts/test.sh
```

脚本检查电源配置解析、模式数值、按电源策略识别、手动模式覆盖，以及只读读取本机设置。实际应用模式时需要 macOS 管理员交互授权。
