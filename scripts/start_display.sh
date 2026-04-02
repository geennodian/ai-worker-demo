#!/usr/bin/env bash
# Xvfb + x11vnc + Chromium を起動する
# 既に systemd で Xvfb/x11vnc が動いている場合はそれを利用する
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-99}"
SCREEN_RES="${SCREEN_RES:-1920x1080x24}"
VNC_PORT="${VNC_PORT:-5900}"
VNC_PASSWD="${VNC_PASSWD:-}"
PIDDIR="/tmp/ai-worker-demo-pids"
CDP_PORT="${CDP_PORT:-9222}"

mkdir -p "$PIDDIR"

export DISPLAY=":${DISPLAY_NUM}"

# --- Xvfb: systemd or manual ---
if xdpyinfo -display ":${DISPLAY_NUM}" >/dev/null 2>&1; then
  echo "Xvfb :${DISPLAY_NUM} は既に起動済み（systemd等）。スキップ。"
else
  echo "=== Xvfb 起動 (DISPLAY=:${DISPLAY_NUM}, ${SCREEN_RES}) ==="
  Xvfb ":${DISPLAY_NUM}" -screen 0 "${SCREEN_RES}" -ac -nolisten tcp &
  echo $! > "$PIDDIR/xvfb.pid"
  sleep 1
fi

# --- x11vnc: systemd or manual ---
if pgrep -f "x11vnc.*:${DISPLAY_NUM}" >/dev/null 2>&1; then
  echo "x11vnc は既に起動済み（systemd等）。スキップ。"
else
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
fi

# --- Chromium: CDP付きで起動（既存のCDP無しChromiumは停止） ---
# CDP が応答するか確認
if curl -s --max-time 2 "http://localhost:${CDP_PORT}/json" >/dev/null 2>&1; then
  echo "Chromium (CDP port ${CDP_PORT}) は既に起動済み。スキップ。"
else
  # CDP無しで動いている Chromium があれば停止
  if pgrep -f "chromium-browser.*no-sandbox" >/dev/null 2>&1; then
    echo "CDP無しの Chromium を検出。停止します..."
    pkill -f "chromium-browser" || true
    sleep 2
  fi

  echo "=== Chromium 起動 (CDP port ${CDP_PORT}) ==="
  chromium-browser \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --remote-debugging-port="${CDP_PORT}" \
    --window-size=1920,1080 \
    --start-maximized \
    --no-first-run \
    --disable-default-apps \
    --disable-extensions-except="" \
    --lang=ja \
    "about:blank" &
  echo $! > "$PIDDIR/chromium.pid"
  sleep 2
fi

# --- 接続情報の表示 ---
TS_IP=$(tailscale ip -4 2>/dev/null || echo "(tailscale未接続)")

echo ""
echo "========================================"
echo "  起動完了"
echo "========================================"
echo "  DISPLAY=:${DISPLAY_NUM}"
echo "  VNC接続先: ${TS_IP}:${VNC_PORT}"
echo "  Chrome DevTools: http://localhost:${CDP_PORT}"
echo "  停止するには: stop_display.sh"
echo "========================================"
