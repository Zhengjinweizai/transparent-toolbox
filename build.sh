#!/bin/bash
set -e
cd "$(dirname "$0")"
mkdir -p build
swiftc -O -swift-version 5 Sources/*.swift -o build/TransparentToolbox
echo "✔ build/TransparentToolbox"
