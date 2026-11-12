import AppKit

private func tr(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var timer: Timer?
    private var mode: GPUMode?
    private var settings = GPUSettings("")
    private var statusText = tr("status.loading")
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
        image.accessibilityDescription = tr("app.name")
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
        statusItem.button?.toolTip = String(format: tr("status.tooltip"), mode?.title ?? tr("status.unknown"))
        menu.removeAllItems()
        let header = NSMenuItem(title: tr("app.name"), action: nil, keyEquivalent: "")
        menu.addItem(header)
        menu.addItem(NSMenuItem(title: switching ? tr("status.switching") : statusText, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        let powerItem = NSMenuItem(title: tr("policy.power.title"), action: #selector(selectPowerPolicy), keyEquivalent: "")
        powerItem.target = self
        powerItem.image = NSImage(systemSymbolName: "powerplug", accessibilityDescription: nil)
        powerItem.state = GPUPolicy.byPowerSource.matches(settings) ? .on : .off
        powerItem.isEnabled = !switching && !settings.profiles.isEmpty
        powerItem.toolTip = tr("policy.power.tooltip")
        menu.addItem(powerItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: tr("menu.manual.header"), action: nil, keyEquivalent: ""))
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
            let title = profile == "AC Power" ? tr("profile.ac") : profile == "Battery Power" ? tr("profile.battery") : profile
            menu.addItem(NSMenuItem(title: String(format: tr("profile.mode"), title, settings.profiles[profile]!.title), action: nil, keyEquivalent: ""))
        }
        let policyText = GPUPolicy.byPowerSource.matches(settings) ? tr("policy.power.enabled") : tr("policy.manual.hint")
        menu.addItem(NSMenuItem(title: policyText, action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        addItem(tr("menu.refresh"), #selector(refresh), "r", enabled: !switching)
        addItem(tr("menu.help"), #selector(showHelp), "")
        addItem(tr("menu.quit"), #selector(quit), "q", enabled: !switching)
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
                    self.statusText = settings.profiles.isEmpty
                        ? tr("status.unsupported")
                        : String(format: tr("status.current"), self.mode?.title ?? tr("status.mixed"))
                case .failure(let error):
                    self.mode = nil
                    self.settings = GPUSettings("")
                    self.statusText = String(format: tr("status.read.error"), error.localizedDescription)
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
                    throw NSError(domain: "IntelMacGraph", code: 1, userInfo: [NSLocalizedDescriptionKey: tr("error.settings.mismatch")])
                }
            }
            DispatchQueue.main.async {
                self.switching = false
                if case .failure(let error) = result, !error.localizedDescription.contains("(-128)") {
                    self.alert(tr("alert.switch.failed"), error.localizedDescription)
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
        alert.addButton(withTitle: tr("button.ok"))
        alert.runModal()
    }

    @objc private func showHelp() {
        alert(tr("help.title"), tr("help.message"))
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
