#!/usr/bin/env bash
# Xvfb + x11vnc + Chromium を停止する
set -euo pipefail

PIDDIR="/tmp/ai-worker-demo-pids"

stop_proc() {
  local name="$1" pidfile="$PIDDIR/$2"
  if [ -f "$pidfile" ]; then
    local pid
    pid=$(cat "$pidfile")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "${name} (PID ${pid}) を停止しました"
    else
      echo "${name} は既に停止しています"
    fi
    rm -f "$pidfile"
  else
    echo "${name}: PIDファイルが見つかりません"
  fi
}

stop_proc "Chromium" "chromium.pid"
stop_proc "x11vnc"  "x11vnc.pid"
stop_proc "Xvfb"    "xvfb.pid"

echo ""
echo "全プロセスを停止しました。"
