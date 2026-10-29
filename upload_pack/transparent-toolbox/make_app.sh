#!/bin/bash
# 打包成 .app bundle（未签名开发者证书，ad-hoc 签名）
set -e
cd "$(dirname "$0")"
./build.sh

APP=build/TransparentToolbox.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# 图标
if [ ! -f build/icon.icns ]; then
  swift scripts/make_icon.swift build/icon_1024.png
  mkdir -p build/icon.iconset
  for s in 16 32 64 128 256 512; do
    sips -z $s $s build/icon_1024.png --out build/icon.iconset/icon_${s}x${s}.png >/dev/null
    d=$((s*2))
    sips -z $d $d build/icon_1024.png --out build/icon.iconset/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns build/icon.iconset -o build/icon.icns
fi

cp build/TransparentToolbox "$APP/Contents/MacOS/TransparentToolbox"
cp build/icon.icns "$APP/Contents/Resources/icon.icns"

cat > "$APP/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>TransparentToolbox</string>
    <key>CFBundleIdentifier</key><string>local.transparent-toolbox</string>
    <key>CFBundleName</key><string>TransparentToolbox</string>
    <key>CFBundleDisplayName</key><string>透明工具箱</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleIconFile</key><string>icon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSScreenCaptureUsageDescription</key><string>取色器需要屏幕录制权限来采样屏幕颜色。</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP" 2>/dev/null || true
echo "✔ $APP"
