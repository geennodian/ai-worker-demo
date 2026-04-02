#!/usr/bin/env bash
# Xvfb + x11vnc + Chromium のインストール（Ubuntu/Debian）
# 初回のみ実行する
set -euo pipefail

echo "=== パッケージインストール ==="
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  xvfb \
  x11vnc \
  chromium-browser \
  fonts-noto-cjk \
  fonts-noto-color-emoji \
  xdotool \
  x11-utils

echo ""
echo "=== インストール完了 ==="
echo "  Xvfb:     $(which Xvfb)"
echo "  x11vnc:   $(which x11vnc)"
echo "  Chromium: $(which chromium-browser)"
echo "  xdotool:  $(which xdotool)"
echo ""
echo "次に start_display.sh を実行してください。"
