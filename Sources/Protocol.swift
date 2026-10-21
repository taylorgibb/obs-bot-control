import Foundation

enum Wire {
    static let frameLength = 60
    static let headerLength = 12
    static let payloadOffset = 16
    static let magic: UInt8 = 0xAA
    static let hostSender: UInt8 = 0x0A
    static let aiReceiver: UInt8 = 0x04
    static let setFlags: UInt8 = 0x25
    static let getFlags: UInt8 = 0x01
    static let replyFlags: UInt8 = 0x29
    static let extensionUnit: UInt8 = 0x02
    static let statusSelector: UInt8 = 0x06
    static let frameSelector: UInt8 = 0x02
    static let aiStatusRequest: UInt16 = 0x0104
    static let trackingTag: UInt8 = 0x16
}

func crc16USB(_ bytes: ArraySlice<UInt8>) -> UInt16 {
    var crc: UInt16 = 0xFFFF
    for byte in bytes {
        crc ^= UInt16(byte)
        for _ in 0..<8 {
            crc = crc & 1 != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1
        }
    }
    return crc ^ 0xFFFF
}

private func store(_ value: UInt16, in bytes: inout [UInt8], at offset: Int) {
    bytes[offset] = UInt8(value & 0xFF)
    bytes[offset + 1] = UInt8(value >> 8)
}

private func load(_ bytes: [UInt8], at offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
}

enum Frame {
    static func build(
        flags: UInt8,
        sequence: UInt16,
        command: UInt16,
        receiver: UInt8 = Wire.aiReceiver,
        payload: [UInt8] = []
    ) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Wire.frameLength)
        bytes[0] = Wire.magic
        bytes[1] = flags
        store(sequence, in: &bytes, at: 2)
        store(UInt16(Wire.headerLength), in: &bytes, at: 4)
        bytes[8] = Wire.hostSender
        bytes[9] = receiver
        store(command, in: &bytes, at: 10)
        store(crc16USB(bytes[0..<Wire.headerLength]), in: &bytes, at: 6)
        guard !payload.isEmpty else { return bytes }
        let end = Wire.payloadOffset + payload.count
        store(UInt16(payload.count), in: &bytes, at: 12)
        bytes.replaceSubrange(Wire.payloadOffset..<end, with: payload)
        store(crc16USB(bytes[12..<end]), in: &bytes, at: 14)
        return bytes
    }

    static func payload(ofReply bytes: [UInt8], sequence: UInt16, command: UInt16) -> [UInt8]? {
        guard bytes.count >= Wire.payloadOffset,
              bytes[0] == Wire.magic,
              bytes[1] == Wire.replyFlags,
              load(bytes, at: 2) == sequence,
              load(bytes, at: 10) == command
        else { return nil }
        var header = Array(bytes[0..<Wire.headerLength])
        store(0, in: &header, at: 6)
        guard crc16USB(header[...]) == load(bytes, at: 6) else { return nil }
        let length = Int(load(bytes, at: 12))
        let end = Wire.payloadOffset + length
        guard end <= bytes.count else { return nil }
        var segment = Array(bytes[12..<end])
        store(0, in: &segment, at: 2)
        guard crc16USB(segment[...]) == load(bytes, at: 14) else { return nil }
        return Array(bytes[Wire.payloadOffset..<end])
    }
}

enum TrackingMode: CaseIterable {
    case normal, upperBody, closeUp, headless, lowerBody, group, hand, whiteboard


    var code: (mode: UInt8, submode: UInt8) {
        switch self {
        case .normal: (2, 0)
        case .upperBody: (2, 1)
        case .closeUp: (2, 2)
        case .headless: (2, 3)
        case .lowerBody: (2, 4)
        case .group: (1, 0)
        case .hand: (3, 0)
        case .whiteboard: (4, 0)
        }
    }
}

enum Tracking: Equatable {
    case disabled
    case mode(TrackingMode)
    case changing
}

enum TrackingStatus {
    static let modeOffset = 0x18
    static let submodeOffset = 0x1C

    static func setCommand(_ mode: TrackingMode?) -> [UInt8] {
        let code = mode?.code ?? (mode: 0, submode: 0)
        var bytes = [UInt8](repeating: 0, count: Wire.frameLength)
        bytes[0] = Wire.trackingTag
        bytes[1] = 2
        bytes[2] = code.mode
        bytes[3] = code.submode
        return bytes
    }

    static func read(_ block: [UInt8]) -> Tracking {
        guard block.count > submodeOffset else { return .changing }
        let pair = (block[modeOffset], block[submodeOffset])
        if pair == (0, 0) { return .disabled }
        let match = TrackingMode.allCases.first { $0.code == (mode: pair.0, submode: pair.1) }
        return match.map(Tracking.mode) ?? .changing
    }
}

enum Gesture: CaseIterable {
    case targetSelect, zoom, dynamicZoom, zoomDirection


    var command: UInt16 {
        switch self {
        case .targetSelect: 0x30C4
        case .zoom: 0x3144
        case .dynamicZoom: 0x3344
        case .zoomDirection: 0x33C4
        }
    }

    var statusOffset: Int {
        switch self {
        case .targetSelect: 3
        case .zoom: 4
        case .dynamicZoom: 5
        case .zoomDirection: 6
        }
    }

    func setFrame(enabled: Bool, sequence: UInt16) -> [UInt8] {
        Frame.build(
            flags: Wire.setFlags,
            sequence: sequence,
            command: command,
            payload: [enabled ? 1 : 0]
        )
    }
}

enum GestureStatus {
    static func request(sequence: UInt16) -> [UInt8] {
        Frame.build(flags: Wire.getFlags, sequence: sequence, command: Wire.aiStatusRequest)
    }

    static func read(reply: [UInt8], sequence: UInt16) -> Set<Gesture>? {
        guard let payload = Frame.payload(ofReply: reply, sequence: sequence, command: Wire.aiStatusRequest),
              payload.count > Gesture.zoomDirection.statusOffset
        else { return nil }
        return Set(Gesture.allCases.filter { payload[$0.statusOffset] != 0 })
    }
}
