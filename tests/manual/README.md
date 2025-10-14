# Phase 2 手動テストガイド

Phase 2-1（カラー出力）とPhase 2-2（設定ファイル対応）の手動テスト環境とシナリオです。

## 📋 目次

1. [クイックスタート](#クイックスタート)
2. [手動テストモード](#手動テストモード)
3. [自動テストシナリオ](#自動テストシナリオ)
4. [テスト項目詳細](#テスト項目詳細)

---

## 🚀 クイックスタート

### 方法1: 自動テストシナリオ（推奨）

一度にすべてのテストを自動実行します：

```bash
cd /path/to/bookmark-cli
bash tests/manual/run_phase2_tests.sh
```

**特徴**:
- ✅ 自動でセットアップ
- ✅ 全テストシナリオを実行
- ✅ 結果を自動集計
- ✅ 手動確認項目の表示

**所要時間**: 約1-2分

---

### 方法2: 手動テストモード

自分でコマンドを実行しながら確認する場合：

```bash
cd /path/to/bookmark-cli

# セットアップ（sourceコマンドで実行）
source tests/manual/setup_phase2_test.sh

# ヘルプ表示
show_phase2_help

# テスト実行（以下は例）
test-proj-a
bmc-test add test1 -d "テストブックマーク" -t test
bmc-test list
bmc-test --no-color add test2

# クリーンアップ
cleanup_phase2_test
```

**特徴**:
- ✅ 各コマンドを手動実行
- ✅ 詳細な動作確認が可能
- ✅ カラー出力を目視確認

**所要時間**: 約5-10分

---

## 🧪 手動テストモード詳細

### セットアップ

```bash
# プロジェクトルートで実行（sourceコマンドを使用）
source tests/manual/setup_phase2_test.sh
```

セットアップされる内容：
- ✅ テストディレクトリ作成（`test_data_phase2/`）
- ✅ テストプロジェクト作成（`proj-a`, `proj-b`, `proj-c`, `proj-d`）
- ✅ 設定ファイルサンプル作成
- ✅ 環境変数設定（`BM_FILE`, `BM_CONFIG`など）
- ✅ エイリアス作成（`bmc-test`, `test-proj-a`など）

### 利用可能なコマンド

#### 基本コマンド
```bash
bmc-test add <name> [path]     # ブックマーク追加
bmc-test list                  # 一覧表示
bmc-test list --tag <tag>      # タグフィルタ
bmc-test go <name>             # パス取得
bmc-test remove <name>         # 削除
bmc-test export <file>         # エクスポート
bmc-test import <file>         # インポート
```

#### ディレクトリ移動
```bash
test-proj-a    # test_data_phase2/test_projects/proj-a へ移動
test-proj-b    # test_data_phase2/test_projects/proj-b へ移動
test-proj-c    # test_data_phase2/test_projects/proj-c へ移動
test-proj-d    # test_data_phase2/test_projects/proj-d へ移動
```

#### 管理コマンド
```bash
show_phase2_help       # ヘルプ表示
cleanup_phase2_test    # テスト環境クリーンアップ
```

---

## 📝 テスト項目詳細

### Phase 2-1: カラー出力テスト

#### Test 1.1: 成功メッセージ（緑色✓）
```bash
test-proj-a
bmc-test add test-color -d "カラーテスト" -t test
```
**期待**: 緑色の✓アイコンと "Bookmark 'test-color' added" が表示

#### Test 1.2: エラーメッセージ（赤色✗）
```bash
bmc-test add test-color
```
**期待**: 赤色の✗アイコンと "already exists" エラー

#### Test 1.3: --no-color（グローバル）
```bash
bmc-test --no-color add test-no-color1 ./test_data_phase2/test_projects/proj-b
```
**期待**: アイコンは表示されるが色なし

#### Test 1.4: --no-color（コマンドレベル）
```bash
bmc-test add --no-color test-no-color2 ./test_data_phase2/test_projects/proj-c
```
**期待**: アイコンは表示されるが色なし

#### Test 1.5: NO_COLOR環境変数
```bash
NO_COLOR=1 bmc-test list
```
**期待**: 色なしで一覧表示

#### Test 1.6: パイプ経由（自動無効化）
```bash
bmc-test list | cat
```
**期待**: 色なしで表示（ターミナル出力でないため）

---

### Phase 2-2: 設定ファイルテスト

#### Test 2.1: 設定ファイルでカラー無効
```bash
export BM_CONFIG="$PWD/test_data_phase2/config_color_disabled"
bmc-test add config-test1 ./test_data_phase2/test_projects/proj-a
```
**期待**: カラーが無効化される

#### Test 2.2: 設定ファイルでNO_COLOR
```bash
export BM_CONFIG="$PWD/test_data_phase2/config_no_color"
bmc-test add config-test2 ./test_data_phase2/test_projects/proj-b
```
**期待**: カラーが無効化される

#### Test 2.3: コメント付き設定ファイル
```bash
export BM_CONFIG="$PWD/test_data_phase2/config_with_comments"
bmc-test add config-test3 ./test_data_phase2/test_projects/proj-c
cat $BM_CONFIG
```
**期待**: コメント行が無視され、設定が読み込まれる

#### Test 2.4: スペースを含む値
```bash
export BM_CONFIG="$PWD/test_data_phase2/config_with_spaces"
source ./cli/bmc.sh
echo "CUSTOM: $CUSTOM_MESSAGE"
echo "QUOTED: $QUOTED_VALUE"
```
**期待**: スペースを含む値が正しく保持される

#### Test 2.5: 環境変数の優先順位
```bash
export BM_CONFIG="$PWD/test_data_phase2/config_color_enabled"
export COLOR_ENABLED=false  # 環境変数で上書き
bmc-test add priority-test ./test_data_phase2/test_projects/proj-a
```
**期待**: 環境変数が優先され、カラー無効

---

### 統合テスト

#### Test 3.1: メタデータ付きブックマーク
```bash
test-proj-a
bmc-test add integrated-test -d "統合テスト" -t phase2,test,integration
```
**期待**: メタデータ付きで追加される

#### Test 3.2: タグフィルタ
```bash
bmc-test list --tag phase2
```
**期待**: phase2タグのブックマークのみ表示

#### Test 3.3: タグ一覧
```bash
bmc-test tags
```
**期待**: すべてのタグが一覧表示

#### Test 3.4: エクスポート・インポート
```bash
bmc-test export test_data_phase2/full_export.json
rm $BM_FILE
bmc-test import test_data_phase2/full_export.json
```
**期待**: メタデータが保持されてエクスポート・インポート

---

## 🧹 クリーンアップ

### 自動クリーンアップ
```bash
cleanup_phase2_test
```

### 手動クリーンアップ
```bash
rm -rf test_data_phase2
unset BM_FILE BM_HISTORY BM_CONFIG XDG_CONFIG_HOME
unalias bmc-test test-proj-a test-proj-b test-proj-c test-proj-d 2>/dev/null
```

---

## 📁 生成されるファイル構造

```
test_data_phase2/
├── bookmarks                          # ブックマークファイル
├── history                            # 履歴ファイル
├── config_color_enabled               # カラー有効設定
├── config_color_disabled              # カラー無効設定
├── config_no_color                    # NO_COLOR設定
├── config_with_comments               # コメント付き設定
├── config_with_spaces                 # スペース含む値
├── xdg_config/
│   └── bookmark-cli/
│       └── config                     # XDG設定
├── home/
│   └── .config/
│       └── bookmark-cli/
│           └── config                 # HOME設定
└── test_projects/
    ├── proj-a/                        # テストプロジェクト
    ├── proj-b/
    ├── proj-c/
    └── proj-d/
```

---

## 🎯 目視確認項目

自動テストでは確認できない項目：

### カラー出力
- [ ] 成功メッセージが**緑色**の✓アイコンで表示される
- [ ] エラーメッセージが**赤色**の✗アイコンで表示される
- [ ] --no-color使用時は色が表示されない
- [ ] アイコン（✓✗ℹ⚠📌🏷️）が正しく表示される

### 設定ファイル
- [ ] BM_CONFIG指定で設定が読み込まれる
- [ ] COLOR_ENABLED=false でカラーが無効化される
- [ ] NO_COLOR=1 でカラーが無効化される
- [ ] 環境変数が設定ファイルより優先される

---

## ⚙️ 設定ファイルの詳細

### config_color_enabled
```bash
COLOR_ENABLED=true
DEFAULT_EDITOR=nano
```

### config_color_disabled
```bash
COLOR_ENABLED=false
DEFAULT_EDITOR=vim
```

### config_no_color
```bash
NO_COLOR=1
```

### config_with_comments
```bash
# This is a comment
COLOR_ENABLED=true

  # Indented comment
DEFAULT_EDITOR=emacs

# Another comment
CUSTOM_VALUE=test123
```

### config_with_spaces
```bash
CUSTOM_MESSAGE=Hello World With Spaces
QUOTED_VALUE="value with spaces"
SINGLE_QUOTED='another value'
```

---

## 🐛 トラブルシューティング

### セットアップが失敗する
```bash
# プロジェクトルートにいるか確認
pwd
ls cli/bmc.sh

# sourceコマンドで実行しているか確認（./ではなく）
source tests/manual/setup_phase2_test.sh
```

### カラーが表示されない
```bash
# ターミナルのカラー対応確認
tput setaf 2 && echo "Green" && tput sgr0

# NO_COLOR環境変数をクリア
unset NO_COLOR

# 設定ファイルを確認
cat $BM_CONFIG
```

### エイリアスが使えない
```bash
# sourceコマンドで実行したか確認
source tests/manual/setup_phase2_test.sh

# エイリアス一覧確認
alias | grep bmc-test
```

---

## 🔧 技術解説: 自動テストと手動テストの違い

### なぜ2つのスクリプトが必要なのか？

#### 自動テストスクリプト (`run_phase2_tests.sh`)
- **実行方法**: `bash tests/manual/run_phase2_tests.sh`
- **動作**: 新しいサブシェルで実行される
- **特徴**:
  - ✅ 完全に自己完結
  - ✅ エイリアス不要（変数でパス指定）
  - ✅ CI/CD環境でも動作
  - ✅ 結果を自動集計

#### 手動テストスクリプト (`setup_phase2_test.sh`)
- **実行方法**: `source tests/manual/setup_phase2_test.sh`
- **動作**: 現在のシェルにロードされる
- **特徴**:
  - ✅ エイリアスが使える
  - ✅ 対話的テストに最適
  - ✅ カラー出力を目視確認可能
  - ✅ 各コマンドを個別実行

### エイリアスの動作原理

**エイリアスの制限**:
```bash
# ❌ サブシェルではエイリアスが継承されない
bash -c "alias bmc-test='./cli/bmc.sh' && bmc-test list"
# → エラー: bmc-test: command not found

# ✅ sourceで現在のシェルにロード
source setup_phase2_test.sh  # エイリアス定義
bmc-test list                # エイリアス使用可能
```

**自動テストの解決策**:
```bash
# エイリアスの代わりに変数を使用
BMC_CMD="$PROJECT_ROOT/cli/bmc.sh"
$BMC_CMD list  # 変数展開で動作
```

### sourceとbashの違い

| 実行方法 | 環境 | エイリアス | 環境変数 | cd有効 |
|---------|------|-----------|---------|--------|
| `source script.sh` | 現在のシェル | ✅ | ✅ | ✅ |
| `bash script.sh` | サブシェル | ❌ | ❌ | ❌ |
| `./script.sh` | サブシェル | ❌ | ❌ | ❌ |

**実例**:
```bash
# 手動テスト（source使用）
source tests/manual/setup_phase2_test.sh
bmc-test add test1  # ✅ エイリアス動作
pwd                 # ✅ cdしたディレクトリにいる

# 自動テスト（bash使用）
bash tests/manual/run_phase2_tests.sh
# ✅ 完全に独立して動作、エイリアス不要
```

---

## 📊 テスト結果の報告

テスト完了後、以下の情報を記録してください：

- [ ] OS/ターミナル環境（macOS Terminal.app, iTerm2, Linux, WSL等）
- [ ] カラー出力の正常性
- [ ] 設定ファイルの読み込み確認
- [ ] 発見した問題や改善点

---

## 次のステップ

Phase 2-1とPhase 2-2のテストが完了したら：

1. **Phase 2-3**: エクスポート形式拡張（TOML/CSV）
2. **Phase 2-4**: インタラクティブモード
3. **Phase 2統合**: 全機能の統合テストとドキュメント作成

---

**作成日**: 2025年10月14日
**対象**: Phase 2-1（カラー出力）& Phase 2-2（設定ファイル対応）
**テスト種別**: 手動テスト + 自動テストシナリオ
