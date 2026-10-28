// Genera Resources/AppIcon.icns: swift Resources/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.first!).deletingLastPathComponent()
let iconset = root.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Forma "squircle" standard di macOS con margine.
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let shape = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(
        starting: NSColor(srgbRed: 0.16, green: 0.47, blue: 0.84, alpha: 1),
        ending: NSColor(srgbRed: 0.06, green: 0.26, blue: 0.51, alpha: 1)
    )!.draw(in: shape, angle: -90)

    // Barre di "spettro" in basso: la verde è il canale libero.
    let bars: [(CGFloat, NSColor)] = [
        (0.55, .white.withAlphaComponent(0.35)), (0.8, .white.withAlphaComponent(0.35)),
        (0.12, NSColor(srgbRed: 0.05, green: 0.64, blue: 0.05, alpha: 1)),
        (0.65, .white.withAlphaComponent(0.35)), (0.4, .white.withAlphaComponent(0.35)),
    ]
    let barArea = NSRect(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.12,
                         width: rect.width * 0.68, height: rect.height * 0.26)
    let barWidth = barArea.width / CGFloat(bars.count) * 0.7
    for (i, bar) in bars.enumerated() {
        let x = barArea.minX + CGFloat(i) * barArea.width / CGFloat(bars.count) + barWidth * 0.2
        let h = max(barArea.height * bar.0, barWidth * 0.5)
        bar.1.setFill()
        NSBezierPath(roundedRect: NSRect(x: x, y: barArea.minY, width: barWidth, height: h),
                     xRadius: barWidth * 0.25, yRadius: barWidth * 0.25).fill()
    }

    // Simbolo Wi‑Fi.
    let config = NSImage.SymbolConfiguration(pointSize: rect.height * 0.42, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "wifi", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let w = symbol.size.width, h = symbol.size.height
        symbol.draw(in: NSRect(x: rect.midX - w / 2, y: rect.minY + rect.height * 0.46, width: w, height: h))
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("AppIcon.icns").path]
try task.run()
task.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("AppIcon.icns creata")
