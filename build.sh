#!/bin/sh
# 커서런.app을 이 폴더에 만든다. 사용: ./build.sh
set -e
cd "$(dirname "$0")"
bundle=커서런.app
app=$bundle/Contents
rm -rf "$bundle"
mkdir -p "$app/MacOS"
swiftc -O CursorRun.swift -o "$app/MacOS/MouseOdometer"
"$app/MacOS/MouseOdometer" --test
# 아이콘: 1024px 원본을 그려서 크기별로 줄인 뒤 icns로 묶는다
set=$(mktemp -d)/AppIcon.iconset
mkdir -p "$set" "$app/Resources"
swift make-icon.swift icon.png
for s in 16 32 128 256 512; do
  sips -z $s $s icon.png --out "$set/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) icon.png --out "$set/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$set" -o "$app/Resources/AppIcon.icns"
# 표시 이름만 커서런이고 번들 ID·실행 파일은 MouseOdometer 그대로다:
# 바꾸면 저장된 기록(defaults 도메인)과 알림 권한이 초기화된다
cat > "$app/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MouseOdometer</string>
<key>CFBundleIdentifier</key><string>MouseOdometer</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleName</key><string>커서런</string>
<key>CFBundleDisplayName</key><string>커서런</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
# 개발자 인증서로 서명하면 다시 빌드해도 입력 모니터링 권한이 유지된다.
# 인증서가 없으면 임시 서명(-)을 쓰고, 그때는 빌드할 때마다 권한을 다시 줘야 한다.
identity=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')
codesign --force -s "${identity:--}" "$bundle"
