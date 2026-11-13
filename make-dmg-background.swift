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

// 배경에 그림을 쓰면 Finder는 아이콘 이름을 화면 모드와 상관없이 검정으로 그리고, 색을 바꿀 설정이 없다.
// 그래서 흰 이름표를 Finder 이름표 바로 아래에 직접 그린다. 배경은 Finder 다크 모드 창과 같은 짙은 회색.
NSColor(white: 0.12, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
// 아이콘 뒤의 순수한 검정 패널: Finder의 검은 이름표가 이 위에 그려져 보이지 않게 된다
NSColor.black.setFill()
NSBezierPath(roundedRect: NSRect(x: 30, y: height - 206, width: 500, height: 178), xRadius: 18, yRadius: 18).fill()

func text(_ string: String, size: Double, weight: NSFont.Weight, top: Double, alpha: Double = 1) {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = 3
    NSString(string: string).draw(
        in: NSRect(x: 40, y: 0, width: width - 80, height: height - top),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
            .paragraphStyle: style,
        ])
}

// 두 아이콘(가운데 y=105) 사이의 화살표
let arrow = NSMutableParagraphStyle()
arrow.alignment = .center
NSString(string: "→").draw(
    in: NSRect(x: 0, y: height - 105 - 30, width: width, height: 60),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 44, weight: .light),
        .foregroundColor: NSColor.white.withAlphaComponent(0.85),
        .paragraphStyle: arrow,
    ])

// 흰 이름표: make-dmg.sh의 아이콘 x 위치와 같아야 한다. Finder의 (안 보이는) 이름표 바로 아래에 둔다
for (name, centerX) in [("커서런", 150.0), ("Applications", 410.0)] {
    NSString(string: name).draw(
        in: NSRect(x: centerX - 80, y: height - 178 - 18, width: 160, height: 18),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.white,
            .paragraphStyle: arrow,  // 가운데 정렬
        ])
}

text("설치 방법", size: 15, weight: .bold, top: 215)
text(
    """
    1. 커서런을 Applications 폴더로 끌어다 놓습니다.
    2. 처음 실행할 때 "확인되지 않은 개발자" 경고가 뜨면
        시스템 설정 → 개인정보 보호 및 보안 → "그래도 열기"를 누릅니다.
    3. 타자 수를 세려면 같은 화면의 "입력 모니터링"에서 커서런을 켜고
        앱을 다시 실행합니다.
    """, size: 12.5, weight: .regular, top: 243, alpha: 0.95)
try! rep.representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
