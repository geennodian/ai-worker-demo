#!/usr/bin/env python3
"""Chromium の CDP 経由で現在のページのテキストを取得する。
remote-debugging-port=9222 で起動済みの Chromium が必要。
"""
import json
import sys
import urllib.request


CDP_BASE = "http://localhost:9222"


def get_active_tab():
    """CDP で開いているタブ一覧から最初の page タブを返す。"""
    try:
        with urllib.request.urlopen(f"{CDP_BASE}/json") as resp:
            tabs = json.loads(resp.read())
    except Exception as e:
        print(f"Error: Chromium に接続できません ({e})", file=sys.stderr)
        print("start_display.sh で Chromium を起動してください。", file=sys.stderr)
        sys.exit(1)

    for tab in tabs:
        if tab.get("type") == "page":
            return tab
    print("Error: page タブが見つかりません", file=sys.stderr)
    sys.exit(1)


def get_page_text_via_cdp(ws_url):
    """CDP の HTTP エンドポイント経由で document.body.innerText を取得する。"""
    # WebSocket を使わず /json/evaluate は存在しないので
    # 代替手段として、ページの URL を取得してから urllib でフェッチする
    # ただしSPAの場合はJSレンダリング結果が必要なので CDP を使う

    # シンプルなアプローチ: CDP HTTP API で Runtime.evaluate を実行
    # urllib だけで WebSocket は扱えないので、簡易的に subprocess で実行
    import subprocess

    script = """
const WebSocket = require('ws');
const ws = new WebSocket(process.argv[1]);
ws.on('open', () => {
    ws.send(JSON.stringify({
        id: 1,
        method: 'Runtime.evaluate',
        params: { expression: 'document.body.innerText' }
    }));
});
ws.on('message', (data) => {
    const msg = JSON.parse(data);
    if (msg.id === 1) {
        console.log(msg.result.result.value || '');
        ws.close();
    }
});
ws.on('error', (e) => { console.error(e.message); process.exit(1); });
"""

    # Node.js + ws が使えるか確認
    try:
        result = subprocess.run(
            ["node", "-e", script, ws_url],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            return result.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Node.js が使えない場合: python-only の簡易フォールバック
    # ページの URL をフェッチしてHTMLからテキストを抽出
    return get_page_text_fallback()


def get_page_text_fallback():
    """CDP からページ URL を取得し、urllib でフェッチしてテキスト抽出する。"""
    import html.parser
    import re

    tab = get_active_tab()
    url = tab.get("url", "")
    if not url or url == "about:blank":
        return ""

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            raw_html = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"Warning: ページ取得失敗 ({e})", file=sys.stderr)
        return ""

    # 簡易 HTML → テキスト変換
    raw_html = re.sub(r"<script[^>]*>.*?</script>", "", raw_html, flags=re.S | re.I)
    raw_html = re.sub(r"<style[^>]*>.*?</style>", "", raw_html, flags=re.S | re.I)
    raw_html = re.sub(r"<[^>]+>", "\n", raw_html)
    raw_html = re.sub(r"\n{3,}", "\n\n", raw_html)

    h = html.parser.HTMLParser()
    text = h.unescape(raw_html).strip()
    # 空行の連続を整理
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    return "\n".join(lines)


def main():
    tab = get_active_tab()
    ws_url = tab.get("webSocketDebuggerUrl", "")

    if ws_url:
        text = get_page_text_via_cdp(ws_url)
    else:
        text = get_page_text_fallback()

    print(text)


if __name__ == "__main__":
    main()
