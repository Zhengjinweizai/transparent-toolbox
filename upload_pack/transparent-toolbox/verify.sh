#!/bin/bash
# 一键自检：构建 → 启动 → 稳定性/状态文件检查
set -e
cd "$(dirname "$0")"

echo "[1/4] 构建…"
./make_app.sh >/dev/null
echo "  ✔ 编译通过"

echo "[2/4] 启动 .app…"
pkill -f "TransparentToolbox.app" 2>/dev/null || true
sleep 1
open build/TransparentToolbox.app
sleep 5
PID=$(pgrep -f "TransparentToolbox.app" | head -1)
if [ -z "$PID" ]; then echo "  ✘ 启动失败"; exit 1; fi
echo "  ✔ 已启动 pid=$PID"

echo "[3/4] 稳定性观察 10s…"
sleep 10
if ! kill -0 "$PID" 2>/dev/null; then echo "  ✘ 进程退出（可能崩溃）"; exit 1; fi
RSS=$(ps -o rss= -p "$PID" | tr -d ' ')
CPU=$(ps -o %cpu= -p "$PID" | tr -d ' ')
echo "  ✔ 存活 RSS=${RSS}KB CPU=${CPU}%"

echo "[4/4] 状态文件…"
STATE="$HOME/Library/Application Support/TransparentToolbox/state.json"
if [ -f "$STATE" ]; then echo "  ✔ $STATE 存在"; else echo "  · 状态文件尚未生成（首次无改动属正常）"; fi

kill "$PID" 2>/dev/null || true
echo "全部通过 ✔"
