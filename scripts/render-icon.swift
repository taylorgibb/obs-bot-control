import AppKit

let canvas = 1024
let glyphScale = 0.56

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: render-icon <output.png>\n".utf8))
    exit(2)
}

let configuration = NSImage.SymbolConfiguration(pointSize: CGFloat(canvas), weight: .regular)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
guard let glyph = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(configuration)
else {
    FileHandle.standardError.write(Data("render-icon: camera.fill is unavailable\n".utf8))
    exit(1)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvas,
    pixelsHigh: canvas,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("render-icon: could not allocate the canvas\n".utf8))
    exit(1)
}

let width = Double(canvas) * glyphScale
let height = width * Double(glyph.size.height) / Double(glyph.size.width)
let target = NSRect(
    x: (Double(canvas) - width) / 2,
    y: (Double(canvas) - height) / 2,
    width: width,
    height: height
)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.black.setFill()
NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()
glyph.draw(in: target)
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("render-icon: could not encode the icon\n".utf8))
    exit(1)
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
