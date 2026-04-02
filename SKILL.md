---
name: ai-worker-demo
description: AI派遣社員のデモ用スキル。ab-hd.co.jpからニュース情報を収集し、Googleスプレッドシートに人間のように転記する。画面共有でのプレゼンテーション向け。「デモして」「ニュース収集して」で起動。「スプシクリアして」「デモリセット」でスプレッドシートの内容を全削除する。
version: 1.0.0
homepage: https://github.com/geennodian/ai-worker-demo
metadata: {"openclaw":{"emoji":"🤖","requires":{"env":["DEMO_SHEET_URL"],"bins":["python3","Xvfb","x11vnc","chromium-browser"]},"primaryEnv":"DEMO_SHEET_URL","install":[{"id":"xvfb","kind":"apt","formula":"xvfb","bins":["Xvfb"],"label":"Xvfb"},{"id":"x11vnc","kind":"apt","formula":"x11vnc","bins":["x11vnc"],"label":"x11vnc"},{"id":"chromium","kind":"apt","formula":"chromium-browser","bins":["chromium-browser"],"label":"Chromium"}]}}
---

# AI派遣社員デモ — ニュース収集 → スプレッドシート転記

## 概要

https://ab-hd.co.jp/ のニュース一覧から最新ニュースを収集し、Googleスプレッドシートに転記する。
デモ用途のため、**すべてのブラウザ操作を人間が操作しているように見せる**。

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

Xvfb, x11vnc, Chromium, 日本語フォント等がインストールされる。

### デモ開始前: 仮想ディスプレイ起動

```bash
bash "$_S/start_display.sh"
```

起動後、以下が表示される:
- `DISPLAY=:99` — 仮想ディスプレイ番号
- `VNC接続先: <Tailscale IP>:5900` — VNC クライアントで接続する

デモを見せる相手には **Tailscale IP:5900** を VNC Viewer で開いてもらう。

### デモ終了後: 停止

```bash
bash "$_S/stop_display.sh"
```

### ブラウザ操作の前提

このスキルのブラウザ操作はすべて **Xvfb 上の Chromium** を対象に行う。
`DISPLAY=:99` 環境で起動した Chromium に対してブラウザツールで操作する。

## スクリプトパスの解決

```bash
_S=$(python3 -c "
import pathlib
hits = sorted(pathlib.Path.home().glob('.openclaw/workspace/skills/*/scripts/format_news.py'))
print(str(hits[-1].parent) if hits else '')
")
[ -z "$_S" ] && echo "スクリプトが見つかりません。スキルを再インストールしてください。" && exit 1
```

---

## 重要: 人間らしい操作ルール

**このスキルの全てのブラウザ操作で以下を厳守する。テンポよく、しかし機械的にならない速度で。**

### クリック
1. クリック対象の要素にまず**ホバー**する
2. **0.15〜0.25秒待機**する
3. その後**クリック**する

### タイピング
1. テキストを**5〜8文字ずつ**に分割する（短いテキストは一括入力OK）
2. 各チャンクを入力した後、**0.1〜0.2秒待機**する

### スクロール
- **scroll_amount は 3** でスクロールする
- スクロール間に **0.3秒程度の間** を置く

### ページ遷移
- ナビゲート後、**0.8〜1秒待機**してページの読み込みを待つ

### セル移動（スプレッドシート）
- セルへの入力後は **Tab キー** で次のセルに移動する
- 行の末尾では **Enter キー** で次の行の先頭に移動する
- 各セル入力前に **0.15秒の間** を置く

---

## 実行手順

### Step 0: Xvfb 環境の確認

1. 以下のコマンドで仮想ディスプレイが起動しているか確認する:
```bash
export DISPLAY=":${DISPLAY_NUM:-99}"
xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && echo "OK" || echo "NG"
```
2. NG の場合は `start_display.sh` を実行して起動する
3. Tailscale IP を確認し、VNC 接続先をユーザーに伝える:
```bash
echo "VNC接続先: $(tailscale ip -4):${VNC_PORT:-5900}"
```

### Step 1: 開始の挨拶

ユーザーに以下のように伝える:
> 「承知しました。ab-hd.co.jp のニュース一覧を確認し、スプレッドシートに転記します。」

### Step 2: ニュースサイトにアクセス

1. https://ab-hd.co.jp/news にナビゲートする
2. 0.8秒待機する

### Step 3: ニュース一覧を確認

1. ページをスクロールしてニュース一覧を確認する
   - scroll_amount: 3 で 1〜2回スクロールする
   - 各スクロール間に 0.3秒の間を置く

### Step 4: ニュース情報を読み取る

ページのテキスト内容を取得し、以下の情報を抽出する:
- 日付
- タイトル
- カテゴリ（タグ）
- 記事URL

抽出した情報を以下の JSON 形式で `/tmp/demo_raw_news.json` に保存する:

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

以下のコマンドを実行してデータを整形する（LLM で処理しない）:

```bash
python3 "$_S/format_news.py" \
  --input /tmp/demo_raw_news.json \
  > /tmp/demo_formatted_news.json
```

`/tmp/demo_formatted_news.json` の内容を読み込み、以降の入力データとして使用する。

### Step 6: スプレッドシートに遷移

1. `$DEMO_SHEET_URL` にナビゲートする
2. 1.5秒待機する（スプレッドシートの読み込みを待つ）

### Step 7: ヘッダー行を入力

セル A1 をクリックし、以下のヘッダーを1セルずつ入力する:

| セル | 内容 |
|------|------|
| A1 | 日付 |
| B1 | タイトル |
| C1 | カテゴリ |
| D1 | URL |

**入力手順（各セル）:**
1. 対象セルにホバー → 0.2秒待機 → クリック
2. テキストを入力（操作ルールに従う）
3. Tab キーで次のセルへ移動

D1 の入力後は Enter キーで A2 に移動する。

### Step 8: ニュースデータを1行ずつ入力

`/tmp/demo_formatted_news.json` の `rows` 配列を順に入力する。

**各行の入力手順:**
1. 日付をタイピング → Tab
2. タイトルをタイピング → Tab
3. カテゴリをタイピング → Tab
4. URLをタイピング → Enter（次の行へ）

- 各セルの入力は「人間らしい操作ルール」のタイピング規則に従う
- 行と行の間に **0.3秒の間** を置く
- 全行の入力が終わるまで繰り返す

### Step 9: 完了確認

1. Ctrl+Home でシートの先頭に戻る

### Step 10: 完了報告

ユーザーに以下の形式で報告する:
> 「ab-hd.co.jp のニュース一覧から {件数} 件の記事情報を収集し、スプレッドシートに転記しました。」

転記した内容の概要（最初の2〜3件のタイトル）も添える。

---

## コマンド対応表

| ユーザーの発言 | 実行する処理 |
|---------------|-------------|
| 「デモして」「ニュース収集して」 | → 上記 Step 0〜10 を実行 |
| 「スプシクリアして」「デモリセット」 | → 下記 スプレッドシートクリア を実行 |

---

## スプレッドシートクリア

デモ後にスプレッドシートの内容を全削除し、次のデモに備える。

### 手順

1. `$DEMO_SHEET_URL` にナビゲートする
2. 1.5秒待機する
3. Ctrl+A で全セルを選択する
4. 0.2秒待機する
5. Delete キーで内容を削除する
6. ユーザーに「スプレッドシートの内容をクリアしました。」と報告する
