#!/usr/bin/env bash
# Xvfb + x11vnc + Chromium を起動する
# Tailscale IP:5900 で VNC 接続可能になる
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-99}"
SCREEN_RES="${SCREEN_RES:-1920x1080x24}"
VNC_PORT="${VNC_PORT:-5900}"
VNC_PASSWD="${VNC_PASSWD:-}"          # 空ならパスワードなし
PIDDIR="/tmp/ai-worker-demo-pids"

mkdir -p "$PIDDIR"

# --- 既存プロセスの確認 ---
if [ -f "$PIDDIR/xvfb.pid" ] && kill -0 "$(cat "$PIDDIR/xvfb.pid")" 2>/dev/null; then
  echo "既に起動済みです。停止するには stop_display.sh を実行してください。"
  echo "  DISPLAY=:${DISPLAY_NUM}"
  TS_IP=$(tailscale ip -4 2>/dev/null || echo "不明")
  echo "  VNC接続先: ${TS_IP}:${VNC_PORT}"
  exit 0
fi

# --- Xvfb 起動 ---
echo "=== Xvfb 起動 (DISPLAY=:${DISPLAY_NUM}, ${SCREEN_RES}) ==="
Xvfb ":${DISPLAY_NUM}" -screen 0 "${SCREEN_RES}" -ac -nolisten tcp &
echo $! > "$PIDDIR/xvfb.pid"
sleep 1

export DISPLAY=":${DISPLAY_NUM}"

# --- x11vnc 起動 ---
VNC_ARGS=(-display ":${DISPLAY_NUM}" -rfbport "${VNC_PORT}" -shared -forever -noxdamage)
if [ -n "$VNC_PASSWD" ]; then
  VNC_ARGS+=(-passwd "$VNC_PASSWD")
else
  VNC_ARGS+=(-nopw)
fi

echo "=== x11vnc 起動 (port ${VNC_PORT}) ==="
x11vnc "${VNC_ARGS[@]}" &
echo $! > "$PIDDIR/x11vnc.pid"
sleep 1

# --- Chromium 起動 ---
echo "=== Chromium 起動 ==="
chromium-browser \
  --no-sandbox \
  --disable-gpu \
  --disable-dev-shm-usage \
  --remote-debugging-port=9222 \
  --window-size=1920,1080 \
  --start-maximized \
  --no-first-run \
  --disable-default-apps \
  --disable-extensions-except="" \
  --lang=ja \
  "about:blank" &
echo $! > "$PIDDIR/chromium.pid"
sleep 2

# --- 接続情報の表示 ---
TS_IP=$(tailscale ip -4 2>/dev/null || echo "(tailscale未接続)")

echo ""
echo "========================================"
echo "  起動完了"
echo "========================================"
echo "  DISPLAY=:${DISPLAY_NUM}"
echo "  VNC接続先: ${TS_IP}:${VNC_PORT}"
if [ -n "$VNC_PASSWD" ]; then
  echo "  VNCパスワード: 設定済み"
else
  echo "  VNCパスワード: なし"
fi
echo ""
echo "  Chrome DevTools: http://localhost:9222"
echo "  VNC Viewer で ${TS_IP}:${VNC_PORT} に接続してください。"
echo "  停止するには: stop_display.sh"
echo "========================================"
