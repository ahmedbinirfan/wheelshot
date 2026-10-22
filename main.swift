import Cocoa
import ServiceManagement

// ponytail: Accessibility only. The scroll-wheel click sends Control-Shift-Command-4.
// Every other button is left alone. macOS takes the screenshot.

final class App: NSObject, NSApplicationDelegate {
    let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var tap: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var listening = false
    var menuMark = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        let image = menuImage()
        image.isTemplate = true
        status.button?.image = image
        status.button?.setAccessibilityLabel("Wheelshot")
        status.menu = NSMenu()
        if !AXIsProcessTrusted() {
            let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        }
        startTap()
        rebuildMenu()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if AXIsProcessTrusted() && self.tap == nil { self.startTap() }
            let mark = "\(AXIsProcessTrusted()) \(self.listening)"
            if mark != self.menuMark {
                self.menuMark = mark
                self.rebuildMenu()
            }
        }
    }

    func rebuildMenu() {
        guard let menu = status.menu else { return }
        menu.removeAllItems()
        let trusted = AXIsProcessTrusted()

        menu.addItem(.sectionHeader(title: "Status"))
        if !trusted {
            menu.addItem(statusLine("Accessibility is off"))
        } else if !listening {
            menu.addItem(statusLine("Not listening yet"))
        } else {
            menu.addItem(statusLine("Listening"))
            menu.addItem(statusLine("Screenshot button: scroll wheel"))
        }

        if !trusted {
            menu.addItem(.sectionHeader(title: "Actions"))
            menu.addItem(item("Turn on Accessibility…", action: #selector(openAccess)))
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("Quit", action: #selector(quit)))
    }

    func menuImage() -> NSImage {
        let side: CGFloat = 18
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.set()
            let weight: CGFloat = 1.35
            func bracket(_ x: CGFloat, _ y: CGFloat, _ dx: CGFloat, _ dy: CGFloat) {
                let path = NSBezierPath()
                path.lineWidth = weight
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                let arm: CGFloat = 4
                path.move(to: NSPoint(x: x + dx * arm, y: y))
                path.line(to: NSPoint(x: x, y: y))
                path.line(to: NSPoint(x: x, y: y + dy * arm))
                path.stroke()
            }
            let edge: CGFloat = 1.2
            bracket(edge, side - edge, 1, -1)
            bracket(side - edge, side - edge, -1, -1)
            bracket(edge, edge, 1, 1)
            bracket(side - edge, edge, -1, 1)
            let wheel = NSBezierPath(ovalIn: NSRect(x: 4.6, y: 4.6, width: 8.8, height: 8.8))
            wheel.lineWidth = 1.15
            wheel.stroke()
            for i in -1...1 {
                let y = side / 2 + CGFloat(i) * 2.1
                let line = NSBezierPath()
                line.lineWidth = 1.15
                line.lineCapStyle = .round
                line.move(to: NSPoint(x: 6.4, y: y))
                line.line(to: NSPoint(x: 11.6, y: y))
                line.stroke()
            }
            NSBezierPath(ovalIn: NSRect(x: 7.85, y: 7.85, width: 2.3, height: 2.3)).fill()
            return true
        }
    }

    func statusLine(_ title: String) -> NSMenuItem {
        let line = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        line.isEnabled = false
        return line
    }

    func item(_ title: String, action: Selector?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc func openAccess() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change login item"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        rebuildMenu()
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func startTap() {
        stopTap()
        let mask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let app = Unmanaged<App>.fromOpaque(refcon).takeUnretainedValue()
                return app.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            listening = false
            DispatchQueue.main.async { self.rebuildMenu() }
            return
        }

        tap = port
        listening = true
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        DispatchQueue.main.async { self.rebuildMenu() }
    }

    func stopTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        listening = false
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // Only the scroll-wheel click. Side buttons pass through.
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        if button != 2 { return Unmanaged.passUnretained(event) }
        if type != .otherMouseDown { return nil }

        DispatchQueue.main.async { self.postScreenshot() }
        return nil
    }

    func postScreenshot() {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
        let control: CGKeyCode = 0x3B
        let shift: CGKeyCode = 0x38
        let command: CGKeyCode = 0x37
        let four: CGKeyCode = 0x15
        func hit(_ code: CGKeyCode, _ down: Bool, _ flags: CGEventFlags) {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
        hit(control, true, .maskControl)
        hit(shift, true, [.maskControl, .maskShift])
        hit(command, true, [.maskControl, .maskShift, .maskCommand])
        hit(four, true, [.maskControl, .maskShift, .maskCommand])
        hit(four, false, [.maskControl, .maskShift, .maskCommand])
        hit(command, false, [.maskControl, .maskShift])
        hit(shift, false, .maskControl)
        hit(control, false, [])
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
