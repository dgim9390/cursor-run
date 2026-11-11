# 커서런

<img src="icon.png" width="128" alt="커서런 아이콘">

마우스 커서가 움직인 거리를 재서 맥 메뉴바에 보여주는 주행거리계.
누적 거리가 "한강 횡단", "에베레스트 등반" 같은 업적 단계를 넘으면 알림이 뜬다.

- 메뉴바: 오늘 이동 거리 (`🖱 1.2km`)
- 메뉴: 오늘·누적 거리, 달성한 업적과 다음 목표, 로그인 시 실행
- 화면의 실제 물리 크기 기준으로 미터 환산 (주 디스플레이 기준)
- 서버 없음, 기록은 이 맥에만 저장

## 빌드

macOS 13 이상과 Xcode 명령줄 도구가 필요하다.

```sh
./build.sh
cp -R 커서런.app ~/Applications/
open ~/Applications/커서런.app
```

## 실행 옵션

```sh
open ~/Applications/커서런.app --args --test-notification   # 테스트 알림 보내기
open ~/Applications/커서런.app --args --ask-notifications   # 알림 허용 창 다시 띄우기
```

## 파일

- `CursorRun.swift` — 앱 전체 (업적 목록은 `milestones`)
- `make-icon.swift` — 아이콘 그리기
- `build.sh` — 앱 번들 만들기

번들 ID와 실행 파일 이름은 `MouseOdometer`다. 바꾸면 저장된 기록과 알림 권한이 초기화된다.
