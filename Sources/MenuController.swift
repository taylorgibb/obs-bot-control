import AppKit
import ServiceManagement

final class MenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let camera = CameraMenu()
    private let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    override init() {
        super.init()
        configureButton()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        camera.install(in: menu)
        menu.addItem(.separator())
        launchAtLogin.target = self
        menu.addItem(launchAtLogin)
        menu.addItem(NSMenuItem(title: "Quit OBS Bot Control", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "OBS Bot Control")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "OBS Bot Control"
        if image == nil {
            button.title = "OBS Bot Control"
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        camera.refresh()
        launchAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        if service.status == .enabled {
            try? service.unregister()
        } else {
            try? service.register()
        }
    }
}
