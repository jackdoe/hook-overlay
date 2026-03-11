import AppKit
import Carbon.HIToolbox

private let keyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29]

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let server = SocketServer()
    private let overlay = OverlayPanel(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
    private var queue: [HookRequest] = []
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var toasts: [ToastPanel] = []
    private static weak var instance: AppDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupEventHandler()
        startServer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        queue.forEach { server.reject($0) }
        queue.removeAll()
        server.stop()
        unregisterHotKeys()
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setStatusIcon(pending: false)
        updateMenu()
    }

    private func setStatusIcon(pending: Bool) {
        guard let button = statusItem.button else { return }
        let name = pending ? "bolt.shield.fill" : "bolt.shield"
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: "HookOverlay")
    }

    private func updateMenu() {
        let menu = NSMenu()
        let pending = NSMenuItem(title: queue.isEmpty ? "No pending requests" : "\(queue.count) pending",
                                 action: nil, keyEquivalent: "")
        pending.isEnabled = false
        menu.addItem(pending)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setupEventHandler() {
        AppDelegate.instance = self
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID), nil,
                                  MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                DispatchQueue.main.async {
                    AppDelegate.instance?.handleHotKey(hotKeyID.id)
                }
                return noErr
            },
            1, &eventType, nil, nil
        )
    }

    private func handleHotKey(_ id: UInt32) {
        guard !queue.isEmpty else { return }
        let count = UInt32(overlay.optionCount)
        switch id {
        case 1: resolve(with: .allow)
        case count: resolve(with: .deny)
        default: resolve(with: .allowAlways)
        }
    }

    private func registerHotKeys(count: Int) {
        unregisterHotKeys()
        let sig = OSType(0x484F4F4B)
        for i in 0..<min(count, keyCodes.count) {
            var ref: EventHotKeyRef?
            if RegisterEventHotKey(keyCodes[i], UInt32(controlKey),
                                   EventHotKeyID(signature: sig, id: UInt32(i + 1)),
                                   GetApplicationEventTarget(), 0, &ref) == noErr {
                hotKeyRefs.append(ref)
            }
        }
    }

    private func unregisterHotKeys() {
        hotKeyRefs.compactMap({ $0 }).forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
    }

    private func startServer() {
        server.onRequest = { [weak self] request in
            switch request.eventType {
            case .permissionRequest:
                self?.enqueue(request)
            case .notification, .stop:
                self?.showToast(for: request)
            }
        }
        do {
            try server.start()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to start socket server"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    private func enqueue(_ request: HookRequest) {
        queue.append(request)
        setStatusIcon(pending: true)
        updateMenu()
        NSSound(named: NSSound.Name("Pop"))?.play()

        if queue.count == 1 {
            showCurrentRequest()
        } else if let current = queue.first {
            overlay.update(request: current, queueCount: queue.count)
        }
    }

    private func showCurrentRequest() {
        guard let current = queue.first else { overlay.dismiss(); return }
        overlay.update(request: current, queueCount: queue.count)
        registerHotKeys(count: overlay.optionCount)
        overlay.show()
    }

    private func resolve(with response: HookResponse) {
        guard !queue.isEmpty else { return }
        let request = queue.removeFirst()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.server.respond(to: request, with: response)
        }
        setStatusIcon(pending: !queue.isEmpty)
        updateMenu()

        if queue.isEmpty {
            unregisterHotKeys()
            overlay.dismiss()
        } else {
            overlay.dismiss { [weak self] in self?.showCurrentRequest() }
        }
    }

    private func showToast(for request: HookRequest) {
        if request.eventType == .stop {
            NSSound(named: NSSound.Name("Glass"))?.play()
        } else {
            NSSound(named: NSSound.Name("Pop"))?.play()
        }

        let toast = ToastPanel()
        toast.update(request: request)
        toasts.append(toast)
        repositionToasts()
        toast.show()

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            toast.dismiss {
                self?.toasts.removeAll { $0 === toast }
                self?.repositionToasts()
            }
        }
    }

    private func repositionToasts() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var y = screen.maxY - 20

        if overlay.isVisible {
            y = overlay.frame.minY - 8
        }

        for toast in toasts {
            let size = toast.frame.size
            y -= size.height
            toast.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 20, y: y))
            y -= 8
        }
    }
}
