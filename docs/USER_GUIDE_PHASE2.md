# bookmark-cli Phase 2 ユーザーガイド

**Phase 2-1: カラー出力機能** & **Phase 2-2: 設定ファイル対応**

---

## 📋 目次

1. [概要](#概要)
2. [Phase 2-1: カラー出力機能](#phase-2-1-カラー出力機能)
3. [Phase 2-2: 設定ファイル対応](#phase-2-2-設定ファイル対応)
4. [実践例](#実践例)
5. [トラブルシューティング](#トラブルシューティング)

---

## 概要

Phase 2-1とPhase 2-2で、bookmark-cliはより見やすく、より設定可能になりました：

### 🎨 Phase 2-1: カラー出力機能
- **成功メッセージが緑色**で表示される
- **エラーメッセージが赤色**で表示される
- **情報メッセージが青色**で表示される
- **警告メッセージが黄色**で表示される
- アイコン（✓✗ℹ⚠📌🏷️）でメッセージの種類を視覚的に区別

### ⚙️ Phase 2-2: 設定ファイル対応
- **設定ファイルでカラーや動作をカスタマイズ**
- **XDG Base Directory準拠**の設定ファイル配置
- **環境変数で柔軟に設定を上書き**
- **コメント付き設定ファイル**で管理しやすい

---

## Phase 2-1: カラー出力機能

### 基本的な使い方

デフォルトでは、ターミナルが対話的な場合に自動的にカラー出力が有効になります：

```bash
# 成功メッセージ（緑色✓）
$ bmc add myproject
✓ Bookmark 'myproject' added

# エラーメッセージ（赤色✗）
$ bmc add myproject
✗ Error: Bookmark 'myproject' already exists

# 情報メッセージ（青色ℹ）
$ bmc list
ℹ Bookmarks (3 total):
NAME        PATH
myproject   /home/user/projects/myproject
docs        /home/user/documents

# タグ情報（🏷️）
$ bmc tags
🏷️ Available tags (5):
  - work (12 bookmarks)
  - personal (5 bookmarks)
```

### カラー出力の無効化

カラー出力が不要な場合、複数の方法で無効化できます：

#### 方法1: NO_COLOR環境変数（推奨）

業界標準の`NO_COLOR`環境変数を使用：

```bash
# 一時的に無効化
$ NO_COLOR=1 bmc list

# シェルセッション全体で無効化
$ export NO_COLOR=1
$ bmc list
$ bmc add newproject
```

#### 方法2: --no-colorオプション（グローバル）

コマンド全体でカラーを無効化：

```bash
$ bmc --no-color add myproject
✓ Bookmark 'myproject' added  # 色なし

$ bmc --no-color list
ℹ Bookmarks (3 total):        # 色なし
```

#### 方法3: --no-colorオプション（コマンドレベル）

特定のサブコマンドでのみ無効化：

```bash
$ bmc add --no-color myproject
✓ Bookmark 'myproject' added  # 色なし
```

#### 方法4: 設定ファイルで無効化

設定ファイルでデフォルトの動作を変更（詳細は次のセクション）：

```bash
# ~/.config/bookmark-cli/config
COLOR_ENABLED=false
```

### パイプ経由時の自動無効化

パイプやリダイレクト使用時、カラーは自動的に無効化されます：

```bash
# 自動的にカラー無効化
$ bmc list | grep myproject
$ bmc list > bookmarks.txt
$ bmc list | less
```

### アイコン一覧

| アイコン | 意味 | 使用場面 |
|---------|------|---------|
| ✓ | 成功 | 追加、削除、更新の成功 |
| ✗ | エラー | コマンド失敗、存在しない項目 |
| ℹ | 情報 | リスト表示、統計情報 |
| ⚠ | 警告 | 重複、非推奨機能 |
| 📌 | ブックマーク | ブックマーク項目 |
| 🏷️ | タグ | タグ関連情報 |

---

## Phase 2-2: 設定ファイル対応

### 設定ファイルの場所

bookmark-cliは以下の順序で設定ファイルを探します：

1. **BM_CONFIG環境変数で指定されたパス**（最優先）
2. **$XDG_CONFIG_HOME/bookmark-cli/config**（XDG準拠）
3. **~/.config/bookmark-cli/config**（デフォルト）

```bash
# 方法1: 環境変数で指定
$ export BM_CONFIG="/path/to/my/config"
$ bmc list

# 方法2: XDG準拠（推奨）
$ export XDG_CONFIG_HOME="$HOME/.config"
$ mkdir -p ~/.config/bookmark-cli
$ touch ~/.config/bookmark-cli/config

# 方法3: デフォルト
$ mkdir -p ~/.config/bookmark-cli
$ touch ~/.config/bookmark-cli/config
```

### 設定ファイルの書き方

設定ファイルは`KEY=VALUE`形式のシンプルな構文です：

```bash
# ~/.config/bookmark-cli/config

# カラー出力の有効/無効
COLOR_ENABLED=true

# デフォルトエディタ
DEFAULT_EDITOR=vim

# カスタム変数も使用可能
CUSTOM_MESSAGE=Hello World
```

### コメントと空行

コメントと空行を自由に使って読みやすく：

```bash
# ~/.config/bookmark-cli/config

# ===========================
# bookmark-cli 設定ファイル
# ===========================

# カラー出力設定
COLOR_ENABLED=true

  # インデント付きコメントもOK
DEFAULT_EDITOR=nano

# 別のセクション
CUSTOM_VALUE=test123
```

### クォートの使用

スペースを含む値はクォートで囲めます：

```bash
# スペース付きの値
CUSTOM_MESSAGE="Hello World With Spaces"
QUOTED_VALUE='another value with spaces'

# クォートなしでもOK（自動的に処理）
SIMPLE_VALUE=no spaces here
```

### 環境変数の優先順位

環境変数は設定ファイルより優先されます：

```bash
# ~/.config/bookmark-cli/config
COLOR_ENABLED=true

# コマンドラインで実行
$ COLOR_ENABLED=false bmc list  # 環境変数が優先されてカラー無効
```

### 利用可能な設定項目

| 設定項目 | 説明 | デフォルト値 | 例 |
|---------|------|-------------|-----|
| `COLOR_ENABLED` | カラー出力の有効化 | `true` | `true` / `false` |
| `NO_COLOR` | カラー出力の無効化 | 未設定 | `1` |
| `DEFAULT_EDITOR` | デフォルトエディタ | `$EDITOR` or `vi` | `vim`, `nano`, `code` |
| `BM_FILE` | ブックマークファイルパス | `~/.local/share/bookmarks` | カスタムパス |
| `BM_HISTORY` | 履歴ファイルパス | `~/.local/share/bm_history` | カスタムパス |

---

## 実践例

### 例1: 職場用と個人用で設定を切り替える

```bash
# 職場用設定
$ cat ~/work/bookmark-config
COLOR_ENABLED=true
DEFAULT_EDITOR=code
BM_FILE=~/work/bookmarks

# 個人用設定
$ cat ~/personal/bookmark-config
COLOR_ENABLED=true
DEFAULT_EDITOR=vim
BM_FILE=~/personal/bookmarks

# 使い分け
$ export BM_CONFIG=~/work/bookmark-config
$ bmc list  # 職場用ブックマーク

$ export BM_CONFIG=~/personal/bookmark-config
$ bmc list  # 個人用ブックマーク
```

### 例2: CI/CD環境でカラーを無効化

```bash
# .gitlab-ci.yml / .github/workflows/xxx.yml
script:
  - export NO_COLOR=1
  - bmc list
  - bmc validate
```

### 例3: スクリプトでの使用

```bash
#!/bin/bash
# backup-bookmarks.sh

# カラーを無効化してログファイルに出力
export NO_COLOR=1

echo "=== Bookmark Backup ===" | tee -a backup.log
bmc list | tee -a backup.log
bmc export backup-$(date +%Y%m%d).json | tee -a backup.log
```

### 例4: プロジェクトごとの設定

```bash
# プロジェクトA用
$ mkdir -p ~/projects/projectA/.config/bookmark-cli
$ cat > ~/projects/projectA/.config/bookmark-cli/config <<EOF
COLOR_ENABLED=true
DEFAULT_EDITOR=code
EOF

# プロジェクトAで作業時
$ cd ~/projects/projectA
$ export XDG_CONFIG_HOME="$PWD/.config"
$ bmc add current-project
```

---

## トラブルシューティング

### Q1: カラーが表示されない

**症状**: `bmc`コマンドを実行してもカラーが表示されない

**原因と対策**:

1. **ターミナルのカラー対応を確認**
   ```bash
   # ターミナルがカラー対応しているか確認
   $ tput setaf 2 && echo "Green" && tput sgr0
   ```

2. **NO_COLOR環境変数をチェック**
   ```bash
   $ echo $NO_COLOR
   # 出力があれば無効化されている
   $ unset NO_COLOR
   ```

3. **設定ファイルを確認**
   ```bash
   $ cat ~/.config/bookmark-cli/config
   # COLOR_ENABLED=false になっていないか確認
   ```

4. **パイプ経由でないか確認**
   ```bash
   # パイプ経由だと自動的に無効化される
   $ bmc list          # カラー有効
   $ bmc list | cat    # カラー無効（自動）
   ```

### Q2: 設定ファイルが読み込まれない

**症状**: 設定ファイルを作成したが反映されない

**原因と対策**:

1. **設定ファイルのパスを確認**
   ```bash
   # デフォルトは ~/.config/bookmark-cli/config
   $ ls -la ~/.config/bookmark-cli/config
   ```

2. **環境変数BM_CONFIGをチェック**
   ```bash
   $ echo $BM_CONFIG
   # 別のパスが設定されていないか確認
   ```

3. **設定ファイルの構文を確認**
   ```bash
   # KEY=VALUE 形式になっているか
   $ cat ~/.config/bookmark-cli/config

   # 正しい例:
   COLOR_ENABLED=true

   # 間違った例:
   COLOR_ENABLED = true  # スペースNG
   COLOR_ENABLED: true   # コロンNG
   ```

4. **環境変数が優先されていないか確認**
   ```bash
   # 環境変数が設定されていると優先される
   $ env | grep COLOR_ENABLED
   $ unset COLOR_ENABLED
   ```

### Q3: エラーメッセージが文字化けする

**症状**: アイコン（✓✗）が文字化けする

**原因と対策**:

1. **ターミナルのUTF-8対応を確認**
   ```bash
   $ echo $LANG
   # en_US.UTF-8 などUTF-8が含まれているか確認

   # 必要に応じて設定
   $ export LANG=en_US.UTF-8
   ```

2. **フォントを確認**
   - ターミナルのフォントがUnicode記号に対応しているか確認
   - 推奨フォント: Nerd Fonts, Cascadia Code, JetBrains Mono

3. **アイコンを無効化したい場合**
   ```bash
   # 現状、アイコン無効化オプションはありませんが、
   # 将来的に追加予定
   # 一時的な回避策: カラー自体を無効化
   $ export NO_COLOR=1
   ```

### Q4: 設定が反映されないコマンドがある

**症状**: 一部のコマンドだけ設定が効かない

**原因と対策**:

1. **コマンドレベルの--no-colorオプションを確認**
   ```bash
   # コマンドレベルオプションが優先される
   $ bmc add --no-color myproject  # 常にカラー無効
   ```

2. **シェルエイリアスを確認**
   ```bash
   $ alias bmc
   # bmc='bmc --no-color' などのエイリアスがないか確認
   ```

3. **設定ファイルの読み込みタイミング**
   ```bash
   # 設定ファイルはコマンド起動時に読み込まれる
   # 変更後は再度コマンドを実行する必要がある
   ```

---

## まとめ

Phase 2-1とPhase 2-2により、bookmark-cliは：

✅ **見やすくなりました** - カラフルなメッセージとアイコン
✅ **カスタマイズ可能になりました** - 設定ファイルで動作を制御
✅ **環境に適応します** - パイプ検出、NO_COLOR対応
✅ **標準に準拠しています** - XDG Base Directory、NO_COLOR標準

次のステップ：
- Phase 2-3: エクスポート形式拡張（TOML/CSV）
- Phase 2-4: インタラクティブモード

---

**作成日**: 2025年10月14日
**対象バージョン**: v0.2.0
**関連ドキュメント**:
- [Phase 2手動テストガイド](../tests/manual/README.md)
- [CLAUDE.md - プロジェクト概要](../CLAUDE.md)
