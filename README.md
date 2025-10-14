# bookmark-cli

Mac/Linux ターミナルでディレクトリをブックマークし、CLI と MCP の両方から操作できるツール。

## 特徴

- 🔖 **簡単ブックマーク**: `bmc add` でディレクトリを瞬時に登録
- 🚀 **高速移動**: `bmc go` で登録したディレクトリに即座に移動
- 🎯 **インタラクティブUI**: `bmc ui` で fzf を使った直感的な操作
- 🎨 **カラー出力**: 成功/エラー/情報を色とアイコンで視覚的に表示
- 🤖 **MCP対応**: LLM（Claude Code等）からプログラマブルに操作
- ⚙️ **柔軟な設定**: 設定ファイル、XDG Base Directory、環境変数対応
- 🔒 **データ保護**: 重複チェック、バックアップ、ロックファイル機能

## インストール

```bash
# フルインストール (CLI + MCP + エイリアス + XDG対応)
curl -sSL https://raw.githubusercontent.com/code-retriever/bookmark-cli/main/install.sh | bash -s -- --with-mcp --alias-bm --xdg

# 標準インストール
curl -sSL https://raw.githubusercontent.com/code-retriever/bookmark-cli/main/install.sh | bash

# XDG Base Directory対応でインストール
./install.sh --xdg
```

### アンインストール

```bash
# アンインストール実行
./install.sh --uninstall

# または、特定の場所からアンインストール
./install.sh --uninstall --prefix=$HOME/.local
```

## 使用方法

### 重要：初回設定

インストール後、シェルを再起動するか以下を実行してください：

```bash
# Bashの場合
source ~/.bashrc

# Zshの場合
source ~/.zshrc

# または新しいターミナルを開く
```

### 基本コマンド

```bash
# ブックマークを追加
bmc add project                              # 現在のディレクトリを 'project' として登録
bmc add work ~/work                          # 指定パスを 'work' として登録
bmc add proj -d "My project" -t work,dev     # 説明とタグ付きで登録

# ブックマークに移動
bmc go project         # 'project' ブックマークへ移動

# ブックマーク一覧
bmc list               # 登録済みブックマークを表示
bmc list --tag work    # 'work' タグのブックマークのみ表示

# タグ管理
bmc tags               # すべてのタグを一覧表示

# インタラクティブUI
bmc ui                 # fzf で選択して移動（説明・タグをプレビュー表示）

# ブックマーク削除
bmc remove project     # 'project' ブックマークを削除
```

> **注意**: `bmc go` でディレクトリ移動を行うには、bmcがシェル関数として読み込まれている必要があります。インストーラーが自動で設定しますが、手動インストールの場合は `source /path/to/bmc.sh` を実行してください。

### カラー出力機能

bookmark-cliは、メッセージをカラフルなアイコン付きで表示します：

```bash
# カラー出力の例
bmc add myproject       # ✓ 成功メッセージ（緑色）
bmc add myproject       # ✗ エラーメッセージ（赤色）
bmc list                # ℹ 情報メッセージ（青色）
```

#### カラー無効化

カラー出力が不要な場合、複数の方法で無効化できます：

```bash
# 方法1: NO_COLOR環境変数（推奨）
NO_COLOR=1 bmc list
export NO_COLOR=1

# 方法2: --no-colorオプション（グローバル）
bmc --no-color add project

# 方法3: --no-colorオプション（コマンドレベル）
bmc add --no-color project

# 方法4: 設定ファイル（後述）
echo "COLOR_ENABLED=false" > ~/.config/bookmark-cli/config
```

**自動無効化**: パイプやリダイレクト使用時、カラーは自動的に無効化されます：
```bash
bmc list | grep project    # カラーなし
bmc list > output.txt      # カラーなし
```

### メタデータ機能（説明・タグ）

```bash
# 説明（description）を追加
bmc add myproject -d "重要なプロジェクト"
bmc add work --description "仕事用ディレクトリ"

# タグ（tags）を追加（カンマ区切り）
bmc add proj1 -t work,important
bmc add proj2 --tags personal,hobby,2024

# 説明とタグを同時に追加
bmc add fullproj -d "フルメタデータのプロジェクト" -t work,dev,test

# タグでフィルタリング
bmc list --tag work        # 'work' タグを持つブックマークのみ表示
bmc list --tag important   # 'important' タグを持つブックマークのみ表示

# すべてのタグを一覧表示
bmc tags                   # タグ一覧と各タグのブックマーク数を表示
```

### 高度な機能

```bash
# 名前変更（メタデータも保持）
bmc rename old_name new_name

# ファイル編集
bmc edit               # $EDITOR でブックマークファイルを開く

# インポート・エクスポート（メタデータ対応）
bmc export backup.json # JSON形式でエクスポート（説明・タグ含む）
bmc import backup.json # JSON形式でインポート（説明・タグ復元）
```

### ブックマーク検証・診断

```bash
# 検証
bmc validate           # 全ブックマークの有効性をチェック
bmc check              # validate のエイリアス

# クリーンアップ
bmc clean              # 無効なブックマークを削除
bmc clean --dry-run    # 削除プレビュー（実際には削除しない）

# 診断
bmc doctor             # 健全性診断とレポート表示
```

### 履歴・頻度追跡

```bash
# 最近使用したブックマーク
bmc recent             # 最近使用した10件を表示
bmc r                  # recent のエイリアス

# 頻繁に使用するブックマーク
bmc frequent           # 使用頻度の高い順に表示

# 統計情報
bmc stats              # 使用統計を表示

# 履歴から選択
bmc go                 # 引数なしで履歴からfzfで選択
```

### エイリアス

| コマンド | エイリアス |
|----------|------------|
| `bmc add` | `bmc a` |
| `bmc go` | `bmc g` |
| `bmc list` | `bmc ls` |
| `bmc ui` | `bmc browse`, `bmc fz` |
| `bmc remove` | `bmc rm`, `bmc del` |
| `bmc rename` | `bmc mv` |
| `bmc edit` | `bmc e` |
| `bmc import` | `bmc imp` |
| `bmc export` | `bmc exp` |
| `bmc validate` | `bmc check` |
| `bmc recent` | `bmc r` |
| `bmc help` | `bmc h` |

## 設定

### 設定ファイル

bookmark-cliは設定ファイルで動作をカスタマイズできます：

#### 設定ファイルの場所

以下の順序で設定ファイルを探します：

1. `$BM_CONFIG`環境変数で指定されたパス（最優先）
2. `$XDG_CONFIG_HOME/bookmark-cli/config`（XDG準拠）
3. `~/.config/bookmark-cli/config`（デフォルト）

#### 設定ファイルの書き方

`KEY=VALUE`形式のシンプルな構文：

```bash
# ~/.config/bookmark-cli/config

# カラー出力の有効/無効
COLOR_ENABLED=true

# デフォルトエディタ
DEFAULT_EDITOR=vim

# コメントと空行も使用可能
# スペース付きの値はクォートで囲む
CUSTOM_MESSAGE="Hello World"
```

#### 利用可能な設定項目

| 設定項目 | 説明 | デフォルト値 |
|---------|------|-------------|
| `COLOR_ENABLED` | カラー出力の有効化 | `true` |
| `NO_COLOR` | カラー出力の無効化 | 未設定 |
| `DEFAULT_EDITOR` | デフォルトエディタ | `$EDITOR` or `vi` |

**注意**: 環境変数は設定ファイルより優先されます。

### 環境変数

- `BM_FILE`: ブックマークファイルの保存先（デフォルト: `~/.bm/bookmarks`）
- `BM_HISTORY`: 履歴ファイルの保存先（デフォルト: `~/.bm/history`）
- `BM_CONFIG`: 設定ファイルのパス
- `EDITOR`: `bmc edit` で使用するエディタ
- `NO_COLOR`: カラー出力を無効化（設定値は任意）
- `COLOR_ENABLED`: カラー出力の有効/無効（`true`/`false`）

### XDG Base Directory 対応

```bash
# XDG対応でインストール
./install.sh --xdg

# 環境変数が自動設定されます
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export BM_FILE="$XDG_DATA_HOME/bookmark-cli/bookmarks"
export BM_HISTORY="$XDG_DATA_HOME/bookmark-cli/history"

# デフォルト保存先
# - ブックマーク: $HOME/.local/share/bookmark-cli/bookmarks
# - 履歴: $HOME/.local/share/bookmark-cli/history
```

**XDG対応の利点**:
- 設定ファイルとデータファイルの分離
- システムの標準的なディレクトリ構造に準拠
- バックアップやマイグレーションが容易

## MCP (Model Context Protocol) 対応

LLM からブックマークを操作できます:

```yaml
# Claude Code での例
{{#tool bookmarks.List}}
{{/tool}}

{{#tool bookmarks.Add}}
{"name": "project", "path": "/path/to/project"}
{{/tool}}
```

## 依存関係

### 必須
- POSIX シェル
- 基本的なユニックスコマンド (`cat`, `grep`, `awk` 等)

### オプション
- `fzf`: インタラクティブUI用
- `jq`: JSON処理用
- Node.js: MCP サーバ用

## 開発

```bash
# テスト実行
npm test
# または
bats tests/

# コードフォーマット
shfmt -w cli/bmc.sh

# 静的解析
shellcheck cli/bmc.sh
```

## ライセンス

MIT License

## 著作権

Copyright (c) 2025 Shinichi Nakazato

MIT License - 詳細は [LICENSE](LICENSE) ファイルを参照

## 貢献

Issue や Pull Request は日本語・英語いずれでも歓迎です。

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチをプッシュ (`git push origin feature/amazing-feature`)
5. Pull Request を作成