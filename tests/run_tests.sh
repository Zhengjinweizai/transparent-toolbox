#!/bin/bash
# 运行单元测试：MathParser（14 用例）+ 数据层迁移/缓冲（5 用例）
set -e
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)

cp tests/test_math.swift "$TMP/math_main.swift" 2>/dev/null || true
[ -f "$TMP/math_main.swift" ] && mv "$TMP/math_main.swift" "$TMP/main.swift" || cp tests/test_math.swift "$TMP/main.swift"
cp Sources/MathParser.swift "$TMP/"
swiftc -O "$TMP/main.swift" "$TMP/MathParser.swift" -o "$TMP/test_math"
"$TMP/test_math" | tail -1

rm -rf "$TMP"; TMP=$(mktemp -d)
cp tests/test_data.swift "$TMP/main.swift"
cp Sources/Store.swift Sources/Theme.swift "$TMP/"
swiftc -O -swift-version 5 "$TMP/main.swift" "$TMP/Store.swift" "$TMP/Theme.swift" -o "$TMP/test_data" 2>/dev/null \
  || swiftc -O -swift-version 5 "$TMP/main.swift" "$TMP/Store.swift" "$TMP/Theme.swift" -o "$TMP/test_data"
"$TMP/test_data" | tail -1
rm -rf "$TMP"
