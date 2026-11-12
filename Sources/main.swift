import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var timer: Timer?
    private var mode: GPUMode?
    private var settings = GPUSettings("")
    private var statusText = "正在读取显卡设置…"
    private var switching = false
    private var refreshing = false
    private lazy var menuIcon: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let chip = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 3.5, width: 11, height: 11), xRadius: 2, yRadius: 2)
            chip.lineWidth = 1.2
            chip.stroke()
            let pins = NSBezierPath()
            pins.lineWidth = 1.2
            pins.lineCapStyle = .round
            for position in [6.0, 9.0, 12.0] {
                pins.move(to: NSPoint(x: position, y: 1.5))
                pins.line(to: NSPoint(x: position, y: 3.5))
                pins.move(to: NSPoint(x: position, y: 14.5))
                pins.line(to: NSPoint(x: position, y: 16.5))
                pins.move(to: NSPoint(x: 1.5, y: position))
                pins.line(to: NSPoint(x: 3.5, y: position))
                pins.move(to: NSPoint(x: 14.5, y: position))
                pins.line(to: NSPoint(x: 16.5, y: position))
            }
            pins.stroke()
            let toggle = NSBezierPath(roundedRect: NSRect(x: 5.5, y: 7, width: 7, height: 4), xRadius: 2, yRadius: 2)
            toggle.lineWidth = 1
            toggle.stroke()
            NSBezierPath(ovalIn: NSRect(x: 9, y: 7.5, width: 3, height: 3)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "显卡开关"
        return image
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Reopening the bundle should not create a second menu bar item.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.IntelMacGraph")
        if others.contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu
        render()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.refresh() }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    private func render() {
        statusItem.button?.title = switching ? " …" : " \(mode?.badge ?? "?")"
        statusItem.button?.image = menuIcon
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.toolTip = "显卡策略：\(mode?.title ?? "未知")"
        menu.removeAllItems()
        let header = NSMenuItem(title: "显卡开关", action: nil, keyEquivalent: "")
        menu.addItem(header)
        menu.addItem(NSMenuItem(title: switching ? "正在等待授权并切换…" : statusText, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let powerItem = NSMenuItem(title: "按电源切换：插电独显 / 电池集显", action: #selector(selectPowerPolicy), keyEquivalent: "")
        powerItem.target = self
        powerItem.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: nil)
        powerItem.state = GPUPolicy.byPowerSource.matches(settings) ? .on : .off
        powerItem.isEnabled = !switching && !settings.profiles.isEmpty
        powerItem.toolTip = "接入电源使用独显，拔掉电源使用集显；由 macOS 自动应用"
        menu.addItem(powerItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "手动选择（覆盖电池与适配器设置）", action: nil, keyEquivalent: ""))
        for value in [GPUMode.automatic, .integrated, .discrete] {
            let item = NSMenuItem(title: "\(value.title)  (\(value.rawValue))", action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.tag = value.rawValue
            item.image = NSImage(systemSymbolName: value.symbol, accessibilityDescription: nil)
            item.state = GPUPolicy.manual(value).matches(settings) ? .on : .off
            item.isEnabled = !switching && !settings.profiles.isEmpty
            item.toolTip = value.command
            menu.addItem(item)
        }
        menu.addItem(.separator())
        for profile in settings.profiles.keys.sorted() {
            let title = profile == "AC Power" ? "电源适配器" : profile == "Battery Power" ? "电池" : profile
            menu.addItem(NSMenuItem(title: "\(title)：\(settings.profiles[profile]!.title)", action: nil, keyEquivalent: ""))
        }
        let policyText = GPUPolicy.byPowerSource.matches(settings) ? "已启用按电源切换" : "选择手动模式将统一所有电源配置"
        menu.addItem(NSMenuItem(title: policyText, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        addItem("刷新状态", #selector(refresh), "r", enabled: !switching)
        addItem("使用说明", #selector(showHelp), "")
        addItem("退出", #selector(quit), "q", enabled: !switching)
    }

    private func addItem(_ title: String, _ action: Selector, _ key: String, enabled: Bool = true) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
    }

    @objc private func refresh() {
        guard !switching, !refreshing else { return }
        refreshing = true
        DispatchQueue.global(qos: .utility).async {
            let result = Result { () -> (GPUSettings, String?) in
                let settings = GPUSettings(try Shell.run("/usr/bin/pmset", ["-g", "custom"]))
                let source = GPUSettings.powerSource(try Shell.run("/usr/bin/pmset", ["-g", "batt"]))
                return (settings, source)
            }
            DispatchQueue.main.async {
                self.refreshing = false
                guard !self.switching else { return }
                switch result {
                case .success(let (settings, source)):
                    self.settings = settings
                    self.mode = settings.mode(for: source)
                    self.statusText = settings.profiles.isEmpty ? "未检测到可切换的显卡设置" : "当前策略：\(self.mode?.title ?? "电源配置不同，状态未知")"
                case .failure(let error):
                    self.mode = nil
                    self.settings = GPUSettings("")
                    self.statusText = "读取失败：\(error.localizedDescription)"
                }
                self.render()
            }
        }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard !switching, let selected = GPUMode(rawValue: sender.tag) else { return }
        // Always apply -a, even if the active source already uses this mode.
        apply(.manual(selected))
    }

    @objc private func selectPowerPolicy() {
        apply(.byPowerSource)
    }

    private func apply(_ policy: GPUPolicy) {
        guard !switching else { return }
        switching = true
        render()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { () -> Void in
                // Only fixed policy commands can reach the elevated command.
                let script = "do shell script \"\(policy.command)\" with administrator privileges"
                _ = try Shell.run("/usr/bin/osascript", ["-e", script])
                let actual = GPUSettings(try Shell.run("/usr/bin/pmset", ["-g", "custom"]))
                guard policy.matches(actual) else {
                    throw NSError(domain: "IntelMacGraph", code: 1, userInfo: [NSLocalizedDescriptionKey: "系统返回的显卡配置与目标不一致，请刷新后重试。"])
                }
            }
            DispatchQueue.main.async {
                self.switching = false
                if case .failure(let error) = result, !error.localizedDescription.contains("(-128)") {
                    self.alert("切换未完成", error.localizedDescription)
                }
                self.refresh()
                self.render()
            }
        }
    }

    private func alert(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc private func showHelp() {
        alert("显卡开关", "按电源切换：电源适配器用独显，电池用集显。配置一次后由 macOS 随电源变化自动应用，退出应用后仍有效。\n\n手动选择：集显 (0)、独显 (1)、自动 (2)。选择任意一项会覆盖所有电源配置，停止按电源切换；再次选择「按电源切换」即可恢复。\n\n菜单栏显示的是当前电源的显卡策略，并非所有应用正在使用的 GPU。\n\n切换时通过系统对话框授权，本应用不读取或保存密码。\n\n外接显示器或部分应用可能需要独显，实际切换受系统与硬件限制。")
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
