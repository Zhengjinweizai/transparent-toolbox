#!/bin/bash
set -e
cd "$(dirname "$0")"
./make_app.sh
rm -f build/TransparentToolbox.dmg
hdiutil create -volname "TransparentToolbox" \
  -srcfolder build/TransparentToolbox.app \
  -ov -format UDZO build/TransparentToolbox.dmg
echo "✔ build/TransparentToolbox.dmg"
