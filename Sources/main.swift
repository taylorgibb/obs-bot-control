import AppKit

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let controller = MenuController()
withExtendedLifetime(controller) {
    application.run()
}
