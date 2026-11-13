#!/bin/sh
# 배포용 DMG를 만든다. 사용: ./build.sh && ./make-dmg.sh  →  CursorRun-<버전>.dmg
# 창 모양을 정할 때 Finder를 조작하므로, 처음 실행하면 Finder 제어 허용을 묻는다.
set -e
cd "$(dirname "$0")"
version=$(defaults read "$PWD/커서런.app/Contents/Info.plist" CFBundleShortVersionString)
work=$(mktemp -d)
stage=$work/커서런
mkdir -p "$stage/.background"
cp -R 커서런.app "$stage/"
# 배포본은 개발자 인증서 대신 임시 서명: 공개 파일에 이름과 팀 ID가 남지 않게 한다
codesign --force -s - "$stage/커서런.app"
ln -s /Applications "$stage/Applications"

# 배경: 1배·2배 해상도를 한 TIFF에 묶어 레티나에서도 선명하게
swift make-dmg-background.swift "$work/bg@2x.png"
sips -z 360 560 "$work/bg@2x.png" --out "$work/bg.png" >/dev/null
tiffutil -cathidpicheck "$work/bg.png" "$work/bg@2x.png" -out "$stage/.background/background.tiff" 2>/dev/null

# 쓰기 가능한 이미지로 만들어 창 모양을 저장한 뒤 압축본으로 바꾼다
hdiutil create -volname 커서런 -srcfolder "$stage" -fs HFS+ -size 20m -ov -format UDRW "$work/rw.dmg" >/dev/null 2>&1
mount=$(hdiutil attach "$work/rw.dmg" -readwrite -noverify -noautoopen 2>/dev/null | awk -F'\t' '/\/Volumes\// {print $NF}')
# 같은 이름의 디스크가 이미 열려 있으면 "커서런 1"로 붙으므로 실제 이름을 넘긴다
osascript - "$(basename "$mount")" <<'EOF'
on run argv
    tell application "Finder"
        tell disk (item 1 of argv)
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            -- 내용 영역 560x360 + 제목 막대 28
            set bounds of container window to {200, 120, 760, 508}
            set opts to icon view options of container window
            set arrangement of opts to not arranged
            set icon size of opts to 96
            set text size of opts to 13
            set background picture of opts to file ".background:background.tiff"
            set position of item "커서런.app" of container window to {150, 105}
            set position of item "Applications" of container window to {410, 105}
            close
            open
            update without registering applications
            delay 1
            close
        end tell
    end tell
end run
EOF
sync
hdiutil detach "$mount" >/dev/null 2>&1
hdiutil convert "$work/rw.dmg" -format UDZO -ov -o "CursorRun-$version.dmg" >/dev/null 2>&1
hdiutil verify "CursorRun-$version.dmg" 2>&1 | tail -1
