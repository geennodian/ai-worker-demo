---
name: ai-worker-demo
description: AI派遣社員のデモ用スキル。ab-hd.co.jpからニュース情報を収集し、Googleスプレッドシートに人間のように転記する。画面共有でのプレゼンテーション向け。「デモして」「ニュース収集して」で起動。「スプシクリアして」「デモリセット」でスプレッドシートの内容を全削除する。
version: 1.1.0
homepage: https://github.com/geennodian/ai-worker-demo
metadata: {"openclaw":{"emoji":"🤖","requires":{"env":["DEMO_SHEET_URL"],"bins":["python3","Xvfb","x11vnc","chromium-browser","xdotool"]},"primaryEnv":"DEMO_SHEET_URL","install":[{"id":"xvfb","kind":"apt","formula":"xvfb","bins":["Xvfb"],"label":"Xvfb"},{"id":"x11vnc","kind":"apt","formula":"x11vnc","bins":["x11vnc"],"label":"x11vnc"},{"id":"chromium","kind":"apt","formula":"chromium-browser","bins":["chromium-browser"],"label":"Chromium"},{"id":"xdotool","kind":"apt","formula":"xdotool","bins":["xdotool"],"label":"xdotool"}]}}
---

# AI派遣社員デモ — ニュース収集 → スプレッドシート転記

## ⚠️ 絶対ルール — 必ず守ること

1. **OpenClaw の `browser` ツール（Playwright / headless）は絶対に使わない。**
   - `browser` action=navigate, snapshot, screenshot, act 等は全て禁止。
   - スクリーンショットを撮って Slack に送信する行為も禁止。
2. **全てのブラウザ操作は `exec` ツールで `xdotool` コマンドを実行して行う。**
3. **ページ内容の取得は `exec` ツールで `python3 "$_S/get_page_text.py"` を実行して行う。**
4. VNC 画面に操作が映ることがこのスキルの目的。headless で動かしたら意味がない。

## 概要

https://ab-hd.co.jp/ のニュース一覧から最新ニュースを収集し、Googleスプレッドシートに転記する。
デモ用途のため、**すべてのブラウザ操作を人間が操作しているように見せる**。

ブラウザ操作は **Xvfb 上の snap 版 Chromium を `xdotool` で制御** する。
VNC 越しにマウスカーソルの動きやキー入力が見える。

Chromium は `--remote-debugging-port=9222` 付きで起動し、
xdotool による画面操作と CDP（`get_page_text.py`）によるページ内容取得を両立する。
既に systemd で Xvfb/x11vnc が常駐している環境では、start_display.sh がそれを検出してスキップする。

## 環境変数

| 変数名 | 内容 |
|--------|------|
| `DEMO_SHEET_URL` | 転記先 Google スプレッドシートの URL |
| `DISPLAY_NUM` | Xvfb ディスプレイ番号（デフォルト: `99`） |
| `VNC_PORT` | VNC 待受ポート（デフォルト: `5900`） |
| `VNC_PASSWD` | VNC パスワード（空ならパスワードなし） |

## Xvfb + VNC 環境のセットアップ

### 初回のみ: パッケージインストール

```bash
bash "$_S/setup_display.sh"
```

### デモ開始前: 仮想ディスプレイ起動

```bash
bash "$_S/start_display.sh"
```

起動後、`VNC接続先: <Tailscale IP>:5900` が表示される。

### デモ終了後: 停止

```bash
bash "$_S/stop_display.sh"
```

## スクリプトパスの解決

```bash
_S=$(python3 -c "
import pathlib
# OpenClaw 環境
hits = sorted(pathlib.Path.home().glob('.openclaw/workspace/skills/ai-worker-demo/scripts/format_news.py'))
if not hits:
    # Claude Code 環境 (fallback)
    hits = sorted(pathlib.Path.home().glob('.claude/skills/*/scripts/format_news.py'))
print(str(hits[-1].parent) if hits else '')
")
[ -z "$_S" ] && echo "スクリプトが見つかりません。スキルを再インストールしてください。" && exit 1
```

---

## ブラウザ操作の方法

**すべてのブラウザ操作は bash コマンドで行う。** 以下の環境変数を各コマンドの先頭で設定すること:

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
```

### URL にナビゲートする

Chromium のアドレスバーにフォーカスし、URLを入力して Enter:

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdotool key ctrl+l
sleep 0.2
xdotool type --delay 20 "https://example.com"
xdotool key Return
sleep 1
```

### マウスを移動してクリックする

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdotool mousemove --sync 500 300
sleep 0.2
xdotool click 1
```

### テキストを入力する

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdotool type --delay 30 "入力するテキスト"
```

`--delay 30` はキー間隔（ミリ秒）。人間らしい速度。

### キーボードショートカット

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdotool key Tab
xdotool key Return
xdotool key ctrl+a
xdotool key ctrl+Home
xdotool key Delete
```

### スクロール

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdotool click --repeat 3 --delay 100 5   # 下スクロール（ボタン5）
xdotool click --repeat 3 --delay 100 4   # 上スクロール（ボタン4）
```

### ページのテキスト内容を取得する

Chromium は `--remote-debugging-port=9222` で起動されている。
ページの内容は以下で取得する:

```bash
python3 "$_S/get_page_text.py"
```

---

## 人間らしい操作ルール

**テンポよく、しかし機械的にならない速度で。**

- **クリック前**: `mousemove` → `sleep 0.2` → `click 1`
- **タイピング**: `xdotool type --delay 30` で入力（30ms/キー = 人間的な速度）
- **スクロール**: `click --repeat 3 --delay 100` で小刻みに
- **ページ遷移後**: `sleep 1` でページ読み込みを待つ
- **セル移動**: `xdotool key Tab` → `sleep 0.15`

---

## コマンド対応表

| ユーザーの発言 | 実行する処理 |
|---------------|-------------|
| 「デモして」「ニュース収集して」 | → デモ実行 (Step 0〜10) |
| 「スプシクリアして」「デモリセット」 | → スプレッドシートクリア |

---

## デモ実行手順

### Step 0: Xvfb 環境の確認

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && echo "OK" || echo "NG"
```

NG の場合は `bash "$_S/start_display.sh"` を実行する。

### Step 1: 開始の挨拶

ユーザーに伝える:
> 「承知しました。ab-hd.co.jp のニュース一覧を確認し、スプレッドシートに転記します。」

### Step 2: ニュースサイトにアクセス

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdotool key ctrl+l
sleep 0.2
xdotool type --delay 20 "https://ab-hd.co.jp/news"
xdotool key Return
sleep 2
```

### Step 3: ニュース一覧をスクロールして確認

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
sleep 0.5
xdotool click --repeat 3 --delay 200 5
sleep 0.5
xdotool click --repeat 3 --delay 200 5
```

### Step 4: ニュース情報を読み取る

ページのテキスト内容を取得する:

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
python3 "$_S/get_page_text.py" > /tmp/demo_page_text.txt
```

取得したテキストを読み、以下の JSON 形式で `/tmp/demo_raw_news.json` に保存する（この抽出は LLM が担当）:

```json
{
  "news": [
    {
      "date": "2024-01-15",
      "title": "ニュースタイトル",
      "category": "カテゴリ名",
      "url": "https://ab-hd.co.jp/news/xxx"
    }
  ]
}
```

### Step 5: データ整形（Python スクリプト）

```bash
python3 "$_S/format_news.py" \
  --input /tmp/demo_raw_news.json \
  > /tmp/demo_formatted_news.json
```

### Step 6: スプレッドシートに遷移

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdotool key ctrl+l
sleep 0.2
xdotool type --delay 15 "$DEMO_SHEET_URL"
xdotool key Return
sleep 3
```

スプレッドシートは読み込みに時間がかかるので 3 秒待つ。

### Step 7: ヘッダー行を入力

セル A1 をクリックし、ヘッダーを入力する:

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
# A1 をクリック（スプレッドシートの左上セル付近）
xdotool mousemove --sync 100 250
sleep 0.2
xdotool click 1
sleep 0.3

# ヘッダー入力
xdotool type --delay 30 "日付"
xdotool key Tab
sleep 0.15
xdotool type --delay 30 "タイトル"
xdotool key Tab
sleep 0.15
xdotool type --delay 30 "カテゴリ"
xdotool key Tab
sleep 0.15
xdotool type --delay 30 "URL"
xdotool key Return
sleep 0.3
```

### Step 8: ニュースデータを1行ずつ入力

`/tmp/demo_formatted_news.json` の `rows` 配列を読み込み、各行を入力する。

**各行の入力（bash で繰り返す）:**

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
# 例: 1行分
xdotool type --delay 30 "$DATE"
xdotool key Tab
sleep 0.15
xdotool type --delay 25 "$TITLE"
xdotool key Tab
sleep 0.15
xdotool type --delay 30 "$CATEGORY"
xdotool key Tab
sleep 0.15
xdotool type --delay 15 "$URL"
xdotool key Return
sleep 0.3
```

上記を `rows` の件数分繰り返す。
入力する値は `/tmp/demo_formatted_news.json` を `python3` や `jq` でパースして取得する。

### Step 9: 完了確認

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdotool key ctrl+Home
```

### Step 10: 完了報告

ユーザーに報告する:
> 「ab-hd.co.jp のニュース一覧から {件数} 件の記事情報を収集し、スプレッドシートに転記しました。」

---

## スプレッドシートクリア

### 手順

```bash
export DISPLAY=":${DISPLAY_NUM:-99}"

# スプレッドシートに遷移
xdotool key ctrl+l
sleep 0.2
xdotool type --delay 15 "$DEMO_SHEET_URL"
xdotool key Return
sleep 3

# 全選択して削除
xdotool key ctrl+a
sleep 0.2
xdotool key Delete
```

ユーザーに「スプレッドシートの内容をクリアしました。」と報告する。
