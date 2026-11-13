// DMG 창 배경(설치 안내 포함)을 2배 해상도 PNG로 그린다. 사용: swift make-dmg-background.swift 출력.png
// 좌표는 make-dmg.sh의 창 크기(560x360)와 아이콘 위치에 맞춰져 있다.
import Cocoa

let width = 560.0, height = 360.0
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(width * 2), pixelsHigh: Int(height * 2), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let scale = NSAffineTransform()
scale.scale(by: 2)
scale.concat()

// 밝은 배경: 배경 그림이 있으면 Finder는 아이콘 이름을 화면 모드와 상관없이 검정으로 그리므로, 그게 잘 읽히는 색
NSColor(white: 0.95, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
let ink = NSColor(white: 0.12, alpha: 1)

func text(_ string: String, size: Double, weight: NSFont.Weight, top: Double, alpha: Double = 1) {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = 3
    NSString(string: string).draw(
        in: NSRect(x: 40, y: 0, width: width - 80, height: height - top),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: ink.withAlphaComponent(alpha),
            .paragraphStyle: style,
        ])
}

// 두 아이콘(가운데 y=105) 사이의 화살표
let center = NSMutableParagraphStyle()
center.alignment = .center
NSString(string: "→").draw(
    in: NSRect(x: 0, y: height - 105 - 30, width: width, height: 60),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 44, weight: .light),
        .foregroundColor: ink.withAlphaComponent(0.6),
        .paragraphStyle: center,
    ])

text("설치 방법", size: 15, weight: .bold, top: 215)
text(
    """
    1. 커서런을 Applications 폴더로 끌어다 놓습니다.
    2. 처음 실행할 때 "확인되지 않은 개발자" 경고가 뜨면
        시스템 설정 → 개인정보 보호 및 보안 → "그래도 열기"를 누릅니다.
    3. 타자 수를 세려면 같은 화면의 "입력 모니터링"에서 커서런을 켜고
        앱을 다시 실행합니다.
    """, size: 12.5, weight: .regular, top: 243, alpha: 0.85)

try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
