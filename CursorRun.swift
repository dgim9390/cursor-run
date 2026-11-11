import Cocoa
import ServiceManagement

func format(_ meters: Double) -> String {
    meters < 1000 ? String(format: "%.1fm", meters) : String(format: "%.2fkm", meters / 1000)
}

func dayString() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

// 기록 메뉴에 보여줄 줄: 최근 날짜부터 30일치, "11월 10일  1.23km · 150타"
func historyLines(_ history: [String: [String: Double]]) -> [String] {
    history.sorted { $0.key > $1.key }.prefix(30).map {
        let date = $0.key.split(separator: "-").dropFirst().compactMap { Int($0) }  // [월, 일]
        let label = date.count == 2 ? "\(date[0])월 \(date[1])일" : $0.key
        return "\(label)  \(format($0.value["m"] ?? 0)) · \(Int($0.value["keys"] ?? 0).formatted())타"
    }
}

final class LoginToggle: NSObject {
    @objc func toggle(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSLog("로그인 항목 변경 실패: \(error)")
        }
        sender.state = service.status == .enabled ? .on : .off
    }
}

if CommandLine.arguments.contains("--test") {
    precondition(
        historyLines(["2026-11-09": ["m": 1234, "keys": 150], "2026-11-10": ["m": 50, "keys": 0]])
            == ["11월 10일  50.0m · 0타", "11월 9일  1.23km · 150타"])
    precondition(historyLines(Dictionary(uniqueKeysWithValues: (100...140).map { ("2026-\($0)", [:]) })).count == 30)
    precondition(format(0) == "0.0m")
    precondition(format(999.94) == "999.9m")
    precondition(format(1234) == "1.23km")
    print("ok")
    exit(0)
}

// shortcut: 주 디스플레이의 물리 크기로만 환산, 외장 모니터 정확도가 필요해지면 화면별로 계산
let display = CGMainDisplayID()
let widthMM = Double(CGDisplayScreenSize(display).width)
let metersPerPoint = widthMM > 0
    ? widthMM / 1000 / Double(CGDisplayBounds(display).width)
    : 0.000264  // 물리 크기를 모르는 디스플레이는 96dpi로 가정

let defaults = UserDefaults.standard
// 저장된 날짜가 오늘이 아니면 첫 refresh()가 그날 기록을 지난 기록으로 넘긴다
var day = defaults.string(forKey: "day") ?? dayString()
var today = defaults.double(forKey: "today")
var history = defaults.dictionary(forKey: "history") as? [String: [String: Double]] ?? [:]
var total = defaults.double(forKey: "total")
var keysToday = defaults.integer(forKey: "keysToday")
var keysTotal = defaults.integer(forKey: "keysTotal")
var last = NSEvent.mouseLocation
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
item.button?.font = .monospacedDigitSystemFont(ofSize: 0, weight: .regular)
let todayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
let totalItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
let menu = NSMenu()
menu.addItem(todayItem)
menu.addItem(totalItem)

// 타자 수: 어떤 키인지는 읽지 않고 눌린 횟수만 센다. 입력 모니터링 권한이 필요하고,
// 권한을 준 뒤에는 앱을 다시 켜야 집계가 시작된다.
final class KeyPermission: NSObject {
    @objc func openSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
}
let keyPermission = KeyPermission()
let keysAllowed = CGPreflightListenEventAccess()
if !keysAllowed { CGRequestListenEventAccess() }
var keyTap: CFMachPort?
keyTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
    eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
    callback: { _, type, event, _ in
        if type == .keyDown {
            // 키를 누르고 있을 때의 자동 반복은 타자로 치지 않는다
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                keysToday += 1
                keysTotal += 1
            }
        } else if let keyTap {
            CGEvent.tapEnable(tap: keyTap, enable: true)  // 시스템이 탭을 끈 경우(타임아웃 등) 다시 켠다
        }
        return Unmanaged.passUnretained(event)
    }, userInfo: nil)
if let keyTap {
    CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, keyTap, 0), .commonModes)
}
let keysItem = NSMenuItem(
    title: "⌨️ 타자 수 켜기: 입력 모니터링 허용 후 앱 재시작…",
    action: keysAllowed ? nil : #selector(KeyPermission.openSettings), keyEquivalent: "")
keysItem.target = keyPermission
menu.addItem(keysItem)
let historyItem = NSMenuItem(title: "📅 기록", action: nil, keyEquivalent: "")
historyItem.submenu = NSMenu()
menu.addItem(historyItem)
func rebuildHistory() {
    historyItem.submenu?.removeAllItems()
    let lines = historyLines(history)
    for line in lines.isEmpty ? ["아직 기록 없음"] : lines {
        historyItem.submenu?.addItem(NSMenuItem(title: line, action: nil, keyEquivalent: ""))
    }
}
rebuildHistory()
menu.addItem(.separator())
let loginToggle = LoginToggle()
let loginItem = NSMenuItem(title: "로그인 시 실행", action: #selector(LoginToggle.toggle(_:)), keyEquivalent: "")
loginItem.target = loginToggle
loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
menu.addItem(loginItem)
menu.addItem(NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
item.menu = menu

NSEvent.addGlobalMonitorForEvents(
    matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
) { _ in
    let p = NSEvent.mouseLocation
    let m = Double(hypot(p.x - last.x, p.y - last.y)) * metersPerPoint
    last = p
    today += m
    total += m
}

func refresh() {
    let now = dayString()
    if now != day {
        if today > 0 || keysToday > 0 {  // 날이 바뀌면 지운 기록을 버리지 않고 날짜별로 남긴다
            history[day] = ["m": today, "keys": Double(keysToday)]
            defaults.set(history, forKey: "history")
            rebuildHistory()
        }
        day = now
        today = 0
        keysToday = 0
    }
    item.button?.title = "🖱 " + format(today) + (keysAllowed ? "  ⌨️ \(keysToday.formatted())" : "")
    if keysAllowed {
        keysItem.title = "⌨️ 타자: 오늘 \(keysToday.formatted())타 · 누적 \(keysTotal.formatted())타"
    }
    todayItem.title = "오늘: " + format(today)
    totalItem.title = "누적: " + format(total)
    defaults.set(day, forKey: "day")
    defaults.set(today, forKey: "today")
    defaults.set(total, forKey: "total")
    defaults.set(keysToday, forKey: "keysToday")
    defaults.set(keysTotal, forKey: "keysTotal")
}

refresh()
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in refresh() }
app.run()
