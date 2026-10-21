import AppKit
import ServiceManagement

final class MenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let camera = CameraMenu()

    override init() {
        super.init()
        configureButton()
        registerLoginItem()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        camera.install(in: menu)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit OBS Bot Control", action: #selector(quitApplication), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func registerLoginItem() {
        let service = SMAppService.mainApp
        if service.status == .notRegistered {
            try? service.register()
        }
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
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
}
