import Cocoa
import ServiceManagement
import UserNotifications

func format(_ meters: Double) -> String {
    meters < 1000 ? String(format: "%.1fm", meters) : String(format: "%.2fkm", meters / 1000)
}

func dayString() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

// 누적 거리 기준, 거리는 대략적인 실제 값
let milestones: [(Double, String)] = [
    (100, "100m 달리기"), (400, "운동장 한 바퀴"), (828, "부르즈 할리파 등반"),
    (1_200, "한강 횡단"), (1_947, "한라산 등반"), (2_744, "백두산 등반"),
    (3_776, "후지산 등반"), (5_000, "5km 달리기"), (8_849, "에베레스트 등반"),
    (10_000, "10km 달리기"), (10_935, "마리아나 해구 잠수"), (21_098, "하프 마라톤"),
    (42_195, "마라톤"), (100_000, "우주 경계(고도 100km) 도달"), (140_000, "서울→대전"),
    (325_000, "서울→부산"), (408_000, "국제우주정거장 고도 도달"), (1_160_000, "서울→도쿄"),
    (4_500_000, "미국 횡단"), (11_000_000, "서울→뉴욕"), (21_196_000, "만리장성 종주"),
    (40_075_000, "지구 한 바퀴"), (384_400_000, "달 도착"),
]

func achievement(_ meters: Double) -> (done: String, next: String) {
    let done = milestones.last { $0.0 <= meters }.map { "\($0.1) 완료" } ?? "아직 업적 없음"
    let next = milestones.first { $0.0 > meters }
        .map { "다음: \($0.1)까지 \(format($0.0 - meters))" } ?? "모든 업적 달성!"
    return (done, next)
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
    precondition(achievement(0) == ("아직 업적 없음", "다음: 100m 달리기까지 100.0m"))
    precondition(achievement(1300) == ("한강 횡단 완료", "다음: 한라산 등반까지 647.0m"))
    precondition(achievement(5e8).next == "모든 업적 달성!")
    precondition(
        historyLines(["2026-11-09": ["m": 1234, "keys": 150], "2026-11-10": ["m": 50, "keys": 0]])
            == ["11월 10일  50.0m · 0타", "11월 9일  1.23km · 150타"])
    precondition(historyLines(Dictionary(uniqueKeysWithValues: (100...140).map { ("2026-\($0)", [:]) })).count == 30)
    precondition(zip(milestones, milestones.dropFirst()).allSatisfy { $0.0 < $1.0 })  // 거리 오름차순
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
// 시작 시점에 이미 달성한 업적은 알리지 않는다
var achieved = milestones.filter { $0.0 <= total }.count
let notifications = UNUserNotificationCenter.current()

// 앱이 활성 상태일 때는 macOS가 배너를 숨기므로, 항상 보이도록 명시한다
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        done([.banner, .list, .sound])
    }
}
let notificationDelegate = NotificationDelegate()
notifications.delegate = notificationDelegate

func notify(_ body: String) {
    let content = UNMutableNotificationContent()
    content.title = "업적 달성"
    content.body = body
    content.sound = .default
    notifications.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) {
        if let error = $0 { NSLog("알림 전송 실패: \(error)") }
    }
}
if CommandLine.arguments.contains("--test-notification") { notify("알림 테스트입니다") }
// 시스템 허용 알림은 오른쪽 위에 작게 떠서 놓치기 쉬워, 먼저 화면 가운데 창으로 묻는다.
// macOS가 최종 허용은 자체 UI에서만 받으므로 그 단계는 없앨 수 없다.
notifications.getNotificationSettings { settings in
    let status = settings.authorizationStatus
    NSLog("알림 권한 상태: \(status.rawValue), 배너: \(settings.alertSetting.rawValue)")
    // --ask-notifications: 이미 허용/거절한 뒤에도 창을 다시 띄운다
    let forced = CommandLine.arguments.contains("--ask-notifications")
    // 권한은 있어도 알림 스타일이 '없음'이면 배너 없이 알림 센터에만 쌓이므로 그때도 묻는다
    let visible = status == .authorized && settings.alertSetting == .enabled
    guard forced || (!visible && !defaults.bool(forKey: "skipNotificationPrompt")) else { return }
    DispatchQueue.main.async {
        let alert = NSAlert()
        alert.messageText = "업적 달성 알림을 켤까요?"
        alert.informativeText = status == .notDetermined
            ? "허용을 누르면 화면 오른쪽 위에 macOS 확인 알림이 뜹니다. 거기서 '허용'을 한 번 더 눌러주세요."
            : "허용을 누르면 시스템 설정의 커서런 알림 화면이 열립니다. '알림 허용'을 켜고 알림 스타일을 '배너'로 바꿔주세요."
        alert.addButton(withTitle: "허용")
        alert.addButton(withTitle: "안 함")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if status == .notDetermined {
                notifications.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            } else {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=MouseOdometer")!)
            }
        } else if !forced {
            defaults.set(true, forKey: "skipNotificationPrompt")
        }
    }
}

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
    title: "타자 수 켜기: 입력 모니터링 허용 후 앱 재시작…",
    action: keysAllowed ? nil : #selector(KeyPermission.openSettings), keyEquivalent: "")
keysItem.target = keyPermission
menu.addItem(keysItem)
let historyItem = NSMenuItem(title: "기록", action: nil, keyEquivalent: "")
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
let doneItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
let nextItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
menu.addItem(doneItem)
menu.addItem(nextItem)
// 업적 전체 목록: 달성한 것에 체크 표시
let achievementsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
achievementsItem.submenu = NSMenu()
for (meters, name) in milestones {
    achievementsItem.submenu?.addItem(
        NSMenuItem(title: "\(name)  \(format(meters))", action: nil, keyEquivalent: ""))
}
menu.addItem(achievementsItem)
func markAchievements(_ count: Int) {
    achievementsItem.title = "업적 전체 (\(count)/\(milestones.count))"
    for (i, item) in (achievementsItem.submenu?.items ?? []).enumerated() {
        item.state = i < count ? .on : .off
    }
}
markAchievements(achieved)
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
    item.button?.title = format(today) + (keysAllowed ? " · \(keysToday.formatted())타" : "")
    if keysAllowed {
        keysItem.title = "타자: 오늘 \(keysToday.formatted())타 · 누적 \(keysTotal.formatted())타"
    }
    todayItem.title = "오늘: " + format(today)
    totalItem.title = "누적: " + format(total)
    (doneItem.title, nextItem.title) = achievement(total)
    let count = milestones.filter { $0.0 <= total }.count
    if count > achieved {
        notify("마우스로 \(milestones[count - 1].1) 완료! (누적 \(format(total)))")
    }
    if count != achieved { markAchievements(count) }
    achieved = count
    defaults.set(day, forKey: "day")
    defaults.set(today, forKey: "today")
    defaults.set(total, forKey: "total")
    defaults.set(keysToday, forKey: "keysToday")
    defaults.set(keysTotal, forKey: "keysTotal")
}

refresh()
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in refresh() }
app.run()
