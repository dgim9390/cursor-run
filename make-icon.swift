// 앱 아이콘 원본(1024px PNG)을 그린다. 사용: swift make-icon.swift 출력.png
import Cocoa

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS 아이콘 규격: 1024 캔버스 안의 824 둥근 사각형
let background = NSBezierPath(
    roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
let dark = NSColor(red: 0.16, green: 0.20, blue: 0.55, alpha: 1)
NSGradient(starting: NSColor(red: 0.36, green: 0.55, blue: 1.0, alpha: 1), ending: dark)!
    .draw(in: background, angle: -90)

func mouse(x: Double, alpha: Double, detail: Bool = false) {
    let rect = NSRect(x: x, y: 312, width: 260, height: 400)
    let body = NSBezierPath(roundedRect: rect, xRadius: 130, yRadius: 130)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    if detail {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 30
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.set()
    }
    NSColor.white.withAlphaComponent(alpha).setFill()
    body.fill()
    guard detail else { return }
    NSShadow().set()
    body.addClip()
    dark.withAlphaComponent(0.4).setStroke()
    let lines = NSBezierPath()
    lines.lineWidth = 10
    lines.move(to: NSPoint(x: rect.minX, y: rect.maxY - 170))  // 버튼 아래 경계
    lines.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 170))
    lines.move(to: NSPoint(x: rect.midX, y: rect.maxY))  // 좌우 버튼 경계
    lines.line(to: NSPoint(x: rect.midX, y: rect.maxY - 170))
    lines.stroke()
    let wheel = NSRect(x: rect.midX - 22, y: rect.maxY - 135, width: 44, height: 90)
    dark.withAlphaComponent(0.75).setFill()
    NSBezierPath(roundedRect: wheel, xRadius: 22, yRadius: 22).fill()
}

// 왼쪽에서 오른쪽으로 움직이는 잔상
let ghosts = 6
for i in 0..<ghosts {
    mouse(x: 150 + Double(i) * 64, alpha: 0.05 + Double(i) * 0.04)
}
mouse(x: 560, alpha: 1, detail: true)

try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
