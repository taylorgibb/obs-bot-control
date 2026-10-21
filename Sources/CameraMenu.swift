import AppKit

private extension TrackingMode {
    var title: String {
        switch self {
        case .normal: "Normal"
        case .upperBody: "Upper Body"
        case .closeUp: "Close-Up"
        case .headless: "Headless"
        case .lowerBody: "Lower Body"
        case .group: "Group"
        case .hand: "Hand"
        case .whiteboard: "Whiteboard"
        }
    }
}

private extension Gesture {
    var title: String {
        switch self {
        case .targetSelect: "Target Select"
        case .zoom: "Zoom"
        case .dynamicZoom: "Dynamic Zoom"
        case .zoomDirection: "Zoom Direction"
        }
    }
}

private extension CameraError {
    var title: String {
        switch self {
        case .notFound: "No Camera Found"
        case .transfer, .noReply: "Camera Not Responding"
        }
    }
}

final class CameraMenu: NSObject {
    private static let settleDelay: TimeInterval = 1.5

    private let controller = CameraController()
    private let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let trackingItem = NSMenuItem(title: "Tracking", action: nil, keyEquivalent: "")
    private let gesturesItem = NSMenuItem(title: "Gestures", action: nil, keyEquivalent: "")
    private let trackingMenu = NSMenu()
    private let gesturesMenu = NSMenu()
    private let disableTracking = NSMenuItem(title: "Disable", action: #selector(turnTrackingOff), keyEquivalent: "")
    private let disableGestures = NSMenuItem(title: "Disable All", action: #selector(turnGesturesOff), keyEquivalent: "")
    private var snapshot: CameraSnapshot?

    override init() {
        super.init()
        header.isEnabled = false

        trackingMenu.autoenablesItems = false
        for mode in TrackingMode.allCases {
            trackingMenu.addItem(entry(mode.title, #selector(chooseTracking(_:)), represents: mode))
        }
        trackingMenu.addItem(.separator())
        disableTracking.target = self
        trackingMenu.addItem(disableTracking)
        trackingItem.submenu = trackingMenu

        gesturesMenu.autoenablesItems = false
        for gesture in Gesture.allCases {
            gesturesMenu.addItem(entry(gesture.title, #selector(toggleGesture(_:)), represents: gesture))
        }
        gesturesMenu.addItem(.separator())
        disableGestures.target = self
        gesturesMenu.addItem(disableGestures)
        gesturesItem.submenu = gesturesMenu

        header.isHidden = true
        trackingItem.isEnabled = false
        gesturesItem.isEnabled = false
    }

    func install(in menu: NSMenu) {
        menu.addItem(header)
        menu.addItem(.separator())
        menu.addItem(trackingItem)
        menu.addItem(gesturesItem)
    }

    private func entry(_ title: String, _ action: Selector, represents value: Any) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        entry.representedObject = value
        return entry
    }

    func refresh() {
        controller.snapshot { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let snapshot): self?.show(snapshot)
                case .failure(let error): self?.showProblem(error)
                }
            }
        }
    }

    private func show(_ snapshot: CameraSnapshot) {
        self.snapshot = snapshot
        header.isHidden = false
        header.title = snapshot.name
        trackingItem.isEnabled = true
        gesturesItem.isEnabled = true
        for entry in trackingMenu.items {
            guard let mode = entry.representedObject as? TrackingMode else { continue }
            entry.state = snapshot.tracking == .mode(mode) ? .on : .off
        }
        disableTracking.state = snapshot.tracking == .disabled ? .on : .off
        for entry in gesturesMenu.items {
            guard let gesture = entry.representedObject as? Gesture else { continue }
            entry.state = snapshot.gestures.contains(gesture) ? .on : .off
        }
    }

    private func showProblem(_ error: CameraError) {
        snapshot = nil
        header.isHidden = false
        header.title = error.title
        trackingItem.isEnabled = false
        gesturesItem.isEnabled = false
    }

    private func applied(_ result: Result<Void, CameraError>) {
        DispatchQueue.main.async { [weak self] in
            switch result {
            case .success:
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { self?.refresh() }
            case .failure(let error):
                self?.showProblem(error)
            }
        }
    }

    @objc private func chooseTracking(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? TrackingMode, var next = snapshot else { return }
        next.tracking = .mode(mode)
        show(next)
        controller.setTracking(mode) { [weak self] in self?.applied($0) }
    }

    @objc private func turnTrackingOff() {
        guard var next = snapshot else { return }
        next.tracking = .disabled
        show(next)
        controller.setTracking(nil) { [weak self] in self?.applied($0) }
    }

    @objc private func toggleGesture(_ sender: NSMenuItem) {
        guard let gesture = sender.representedObject as? Gesture, var next = snapshot else { return }
        let enabled = !next.gestures.contains(gesture)
        if enabled { next.gestures.insert(gesture) } else { next.gestures.remove(gesture) }
        show(next)
        controller.setGestures([(gesture, enabled)]) { [weak self] in self?.applied($0) }
    }

    @objc private func turnGesturesOff() {
        guard var next = snapshot else { return }
        next.gestures = []
        show(next)
        controller.setGestures(Gesture.allCases.map { ($0, false) }) { [weak self] in self?.applied($0) }
    }
}
