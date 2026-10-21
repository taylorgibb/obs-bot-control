import Foundation

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
}

func name(_ tracking: Tracking) -> String {
    switch tracking {
    case .disabled: "disabled"
    case .changing: "changing"
    case .mode(let mode): "\(mode)"
    }
}

func trimmed(_ bytes: [UInt8]) -> [UInt8] {
    var end = bytes.count
    while end > 0 && bytes[end - 1] == 0 { end -= 1 }
    return Array(bytes[0..<end])
}

let exposure = Frame.build(flags: Wire.setFlags, sequence: 0x16, command: 0x2982, receiver: 0x02, payload: [2, 4, 0, 0, 0])
print("exposure \(hex(trimmed(exposure)))")

for gesture in Gesture.allCases {
    for enabled in [true, false] {
        let frame = gesture.setFrame(enabled: enabled, sequence: 0x16)
        print("\(gesture) \(enabled ? "on" : "off") \(hex(Array(frame[0..<17])))")
    }
}

print("status request \(hex(Array(GestureStatus.request(sequence: 0x4C04)[0..<12])))")

var reply = [UInt8](repeating: 0, count: Wire.frameLength)
let captured: [UInt8] = [
    0xaa, 0x29, 0x04, 0x4c, 0x0c, 0x00, 0x42, 0x09, 0x04, 0x0a, 0x04, 0x01, 0x0c, 0x00, 0xd1, 0x9b,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00,
]
reply.replaceSubrange(0..<captured.count, with: captured)
let read = GestureStatus.read(reply: reply, sequence: 0x4C04)
print("captured reply \(read.map { Gesture.allCases.filter($0.contains).map { "\($0)" }.joined(separator: ",") } ?? "rejected")")
print("wrong sequence \(GestureStatus.read(reply: reply, sequence: 0x4C05) == nil ? "rejected" : "accepted")")
var corrupted = reply
corrupted[19] = 0
print("corrupted payload \(GestureStatus.read(reply: corrupted, sequence: 0x4C04) == nil ? "rejected" : "accepted")")

var block = [UInt8](repeating: 0, count: Wire.frameLength)
print("tracking idle \(name(TrackingStatus.read(block)))")
block[0x18] = 2
block[0x1C] = 1
print("tracking upper \(name(TrackingStatus.read(block)))")
block[0x18] = 6
block[0x1C] = 0
print("tracking transient \(name(TrackingStatus.read(block)))")
print("tracking set \(hex(Array(TrackingStatus.setCommand(.closeUp)[0..<4])))")
print("tracking off \(hex(Array(TrackingStatus.setCommand(nil)[0..<4])))")
