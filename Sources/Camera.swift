import Foundation
import IOKit
import IOUSBHost

enum CameraError: Error {
    case notFound
    case transfer
    case noReply
}

struct CameraSnapshot {
    let name: String
    var tracking: Tracking
    var gestures: Set<Gesture>
}

final class CameraLink {
    static let vendor = 0x3564
    static let products = [0xFEF8, 0xFEF9]
    private static let transferTimeout: TimeInterval = 1
    private static let replyAttempts = 10
    private static let replyDelay: TimeInterval = 0.05

    let name: String
    private let device: IOUSBHostDevice

    private init(device: IOUSBHostDevice, name: String) {
        self.device = device
        self.name = name
    }

    deinit {
        device.destroy()
    }

    static func connect() throws -> CameraLink {
        for product in products {
            let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary
            matching["idVendor"] = vendor
            matching["idProduct"] = product
            let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
            guard service != 0 else { continue }
            defer { IOObjectRelease(service) }
            let property = IORegistryEntryCreateCFProperty(service, "USB Product Name" as CFString, kCFAllocatorDefault, 0)
            let name = property?.takeRetainedValue() as? String ?? "Camera"
            guard let device = try? IOUSBHostDevice(__ioService: service, options: [], queue: nil, interestHandler: nil) else {
                throw CameraError.transfer
            }
            return CameraLink(device: device, name: name)
        }
        throw CameraError.notFound
    }

    private func transfer(type: UInt8, request: UInt8, selector: UInt8, data: [UInt8]) throws -> [UInt8] {
        let control = IOUSBDeviceRequest(
            bmRequestType: type,
            bRequest: request,
            wValue: UInt16(selector) << 8,
            wIndex: UInt16(Wire.extensionUnit) << 8,
            wLength: UInt16(Wire.frameLength)
        )
        let buffer = NSMutableData(length: Wire.frameLength)!
        buffer.replaceBytes(in: NSRange(location: 0, length: data.count), withBytes: data)
        var transferred = 0
        do {
            try device.__send(control, data: buffer, bytesTransferred: &transferred, completionTimeout: Self.transferTimeout)
        } catch {
            throw CameraError.transfer
        }
        return Array(UnsafeBufferPointer(start: buffer.bytes.assumingMemoryBound(to: UInt8.self), count: transferred))
    }

    private func write(selector: UInt8, _ data: [UInt8]) throws {
        _ = try transfer(type: 0x21, request: 0x01, selector: selector, data: data)
    }

    private func read(selector: UInt8) throws -> [UInt8] {
        try transfer(type: 0xA1, request: 0x81, selector: selector, data: [])
    }

    func trackingStatus() throws -> Tracking {
        TrackingStatus.read(try read(selector: Wire.statusSelector))
    }

    func setTracking(_ mode: TrackingMode?) throws {
        try write(selector: Wire.statusSelector, TrackingStatus.setCommand(mode))
    }

    func setGesture(_ gesture: Gesture, enabled: Bool, sequence: UInt16) throws {
        try write(selector: Wire.frameSelector, gesture.setFrame(enabled: enabled, sequence: sequence))
    }

    func gestures(sequence: UInt16) throws -> Set<Gesture> {
        try write(selector: Wire.frameSelector, GestureStatus.request(sequence: sequence))
        for _ in 0..<Self.replyAttempts {
            Thread.sleep(forTimeInterval: Self.replyDelay)
            let reply = try read(selector: Wire.frameSelector)
            if let gestures = GestureStatus.read(reply: reply, sequence: sequence) { return gestures }
        }
        throw CameraError.noReply
    }
}

final class CameraController {
    private let queue = DispatchQueue(label: "io.github.taylorgibb.obs-bot-control.camera")
    private var sequence = UInt16.random(in: 1...UInt16.max)

    private func nextSequence() -> UInt16 {
        sequence = sequence == UInt16.max ? 1 : sequence + 1
        return sequence
    }

    func snapshot(_ completion: @escaping (Result<CameraSnapshot, CameraError>) -> Void) {
        queue.async {
            completion(self.attempt {
                let link = try CameraLink.connect()
                return CameraSnapshot(
                    name: link.name,
                    tracking: try link.trackingStatus(),
                    gestures: try link.gestures(sequence: self.nextSequence())
                )
            })
        }
    }

    func setTracking(_ mode: TrackingMode?, _ completion: @escaping (Result<Void, CameraError>) -> Void) {
        queue.async {
            completion(self.attempt { try CameraLink.connect().setTracking(mode) })
        }
    }

    func setGestures(_ changes: [(Gesture, Bool)], _ completion: @escaping (Result<Void, CameraError>) -> Void) {
        queue.async {
            completion(self.attempt {
                let link = try CameraLink.connect()
                for (gesture, enabled) in changes {
                    try link.setGesture(gesture, enabled: enabled, sequence: self.nextSequence())
                }
            })
        }
    }

    private func attempt<Value>(_ work: () throws -> Value) -> Result<Value, CameraError> {
        do {
            return .success(try work())
        } catch let error as CameraError {
            return .failure(error)
        } catch {
            return .failure(.transfer)
        }
    }
}
