#!/bin/bash

# Phase 2 テストシナリオ自動実行スクリプト
# 使い方: bash tests/manual/run_phase2_tests.sh
#
# 注意: このスクリプトはbashで直接実行します（sourceではない）
# エイリアスは使わず、変数とコマンドパスで完全に自己完結します

# カラー出力
COLOR_GREEN="\033[0;32m"
COLOR_BLUE="\033[0;34m"
COLOR_YELLOW="\033[0;33m"
COLOR_RED="\033[0;31m"
COLOR_RESET="\033[0m"

# プロジェクトルートディレクトリの検出
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Phase 2 自動テストシナリオ${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""

# プロジェクトルート確認
if [ ! -f "$PROJECT_ROOT/cli/bmc.sh" ]; then
    echo -e "${COLOR_RED}✗ エラー: cli/bmc.sh が見つかりません${COLOR_RESET}"
    echo "プロジェクトルート: $PROJECT_ROOT"
    exit 1
fi

echo -e "${COLOR_GREEN}✓${COLOR_RESET} プロジェクトルート: $PROJECT_ROOT"

# ========================================
# セットアップ
# ========================================

# テストディレクトリの作成
TEST_DATA_DIR="$PROJECT_ROOT/test_data_phase2"
TEST_PROJECTS_DIR="$TEST_DATA_DIR/test_projects"

# 既存のテストデータをクリーンアップ
if [ -d "$TEST_DATA_DIR" ]; then
    echo -e "${COLOR_YELLOW}既存のテストデータを削除しています...${COLOR_RESET}"
    rm -rf "$TEST_DATA_DIR"
fi

echo -e "${COLOR_GREEN}✓${COLOR_RESET} テストディレクトリを作成"
mkdir -p "$TEST_DATA_DIR"
mkdir -p "$TEST_PROJECTS_DIR/proj-"{a,b,c,d}

# テスト用の設定ファイルを作成
cat > "$TEST_DATA_DIR/config_color_enabled" <<'EOF'
# bookmark-cli configuration - カラー有効
COLOR_ENABLED=true
DEFAULT_EDITOR=nano
EOF

cat > "$TEST_DATA_DIR/config_color_disabled" <<'EOF'
# bookmark-cli configuration - カラー無効
COLOR_ENABLED=false
DEFAULT_EDITOR=vim
EOF

cat > "$TEST_DATA_DIR/config_no_color" <<'EOF'
# bookmark-cli configuration - NO_COLOR指定
NO_COLOR=1
EOF

cat > "$TEST_DATA_DIR/config_with_comments" <<'EOF'
# This is a comment
COLOR_ENABLED=true

  # Indented comment
DEFAULT_EDITOR=emacs

# Another comment
CUSTOM_VALUE=test123
EOF

echo -e "${COLOR_GREEN}✓${COLOR_RESET} 設定ファイルを作成"

# 環境変数を設定
export BM_FILE="$TEST_DATA_DIR/bookmarks"
export BM_HISTORY="$TEST_DATA_DIR/history"
export BM_CONFIG="$TEST_DATA_DIR/config_color_enabled"

# bmcコマンドのパス（エイリアスの代わり）
BMC_CMD="$PROJECT_ROOT/cli/bmc.sh"

echo ""
echo -e "${COLOR_BLUE}環境変数を設定:${COLOR_RESET}"
echo "  BM_FILE=$BM_FILE"
echo "  BM_HISTORY=$BM_HISTORY"
echo "  BM_CONFIG=$BM_CONFIG"
echo "  BMC_CMD=$BMC_CMD"
echo ""

# ========================================
# テスト実行
# ========================================

# テスト結果カウンタ
PASS_COUNT=0
FAIL_COUNT=0

# テスト関数
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"

    echo -e "\n${COLOR_BLUE}テスト: $test_name${COLOR_RESET}"
    echo "コマンド: $test_command"

    # コマンド実行
    output=$(eval "$test_command" 2>&1)
    exit_code=$?

    # 結果表示
    echo "$output"

    # パターンマッチング（指定されている場合）
    if [ -n "$expected_pattern" ]; then
        if echo "$output" | grep -q "$expected_pattern"; then
            echo -e "${COLOR_GREEN}✓ PASS${COLOR_RESET}"
            ((PASS_COUNT++))
            return 0
        else
            echo -e "${COLOR_RED}✗ FAIL (期待: $expected_pattern)${COLOR_RESET}"
            ((FAIL_COUNT++))
            return 1
        fi
    else
        if [ $exit_code -eq 0 ]; then
            echo -e "${COLOR_GREEN}✓ PASS${COLOR_RESET}"
            ((PASS_COUNT++))
            return 0
        else
            echo -e "${COLOR_RED}✗ FAIL (exit code: $exit_code)${COLOR_RESET}"
            ((FAIL_COUNT++))
            return 1
        fi
    fi
}

echo ""
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Phase 2-1: カラー出力テスト${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"

# Test 1.1: 成功メッセージ（カラー有効）
cd "$TEST_PROJECTS_DIR/proj-a" || exit 1
run_test "カラー有効での追加" \
    "$BMC_CMD add test-color -d 'カラーテスト' -t test" \
    "Bookmark 'test-color' added"

# Test 1.2: エラーメッセージ（重複）
run_test "重複エラー" \
    "$BMC_CMD add test-color 2>&1" \
    "already exists"

# Test 1.3: --no-color オプション（グローバル）
run_test "--no-color グローバルオプション" \
    "$BMC_CMD --no-color add test-no-color1 $TEST_PROJECTS_DIR/proj-b" \
    "Bookmark 'test-no-color1' added"

# Test 1.4: --no-color オプション（コマンドレベル）
run_test "--no-color コマンドレベル" \
    "$BMC_CMD add --no-color test-no-color2 $TEST_PROJECTS_DIR/proj-c" \
    "Bookmark 'test-no-color2' added"

# Test 1.5: NO_COLOR環境変数
run_test "NO_COLOR環境変数" \
    "NO_COLOR=1 $BMC_CMD list" \
    "test-color"

# Test 1.6: リスト表示
run_test "リスト表示" \
    "$BMC_CMD list" \
    "NAME"

echo ""
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Phase 2-2: 設定ファイルテスト${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"

# Test 2.1: 設定ファイルでカラー無効
run_test "設定ファイル（カラー無効）" \
    "BM_CONFIG=$TEST_DATA_DIR/config_color_disabled $BMC_CMD add config-test1 $TEST_PROJECTS_DIR/proj-a" \
    "Bookmark 'config-test1' added"

# Test 2.2: 設定ファイルでNO_COLOR
run_test "設定ファイル（NO_COLOR）" \
    "BM_CONFIG=$TEST_DATA_DIR/config_no_color $BMC_CMD add config-test2 $TEST_PROJECTS_DIR/proj-b" \
    "Bookmark 'config-test2' added"

# Test 2.3: コメント付き設定ファイル
run_test "設定ファイル（コメント付き）" \
    "BM_CONFIG=$TEST_DATA_DIR/config_with_comments $BMC_CMD add config-test3 $TEST_PROJECTS_DIR/proj-c" \
    "Bookmark 'config-test3' added"

# Test 2.4: エクスポート
run_test "エクスポート" \
    "$BMC_CMD export $TEST_DATA_DIR/export_test.json" \
    "Exported"

# Test 2.5: インポート
run_test "インポート（準備）" \
    "rm -f $BM_FILE"

run_test "インポート" \
    "$BMC_CMD import $TEST_DATA_DIR/export_test.json" \
    "Imported"

# Test 2.6: リネーム
run_test "リネーム" \
    "$BMC_CMD rename test-color test-renamed" \
    "renamed to 'test-renamed'"

# Test 2.7: 削除
run_test "削除" \
    "$BMC_CMD remove test-renamed" \
    "removed"

echo ""
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}統合テスト${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"

# Test 3.1: メタデータ付きブックマーク
cd "$TEST_PROJECTS_DIR/proj-a" || exit 1
run_test "メタデータ付き追加" \
    "$BMC_CMD add integrated-test -d '統合テスト' -t phase2,test,integration" \
    "Bookmark 'integrated-test' added"

# Test 3.2: タグフィルタ
run_test "タグフィルタ" \
    "$BMC_CMD list --tag phase2" \
    "integrated-test"

# Test 3.3: タグ一覧
run_test "タグ一覧" \
    "$BMC_CMD tags" \
    "phase2"

# Test 3.4: 検証
run_test "検証" \
    "$BMC_CMD validate" \
    ""

echo ""
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}テスト結果${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""
echo -e "成功: ${COLOR_GREEN}$PASS_COUNT${COLOR_RESET}"
echo -e "失敗: ${COLOR_RED}$FAIL_COUNT${COLOR_RESET}"
echo -e "合計: $((PASS_COUNT + FAIL_COUNT))"
echo ""

# 手動確認項目
echo -e "${COLOR_YELLOW}========================================${COLOR_RESET}"
echo -e "${COLOR_YELLOW}手動確認項目${COLOR_RESET}"
echo -e "${COLOR_YELLOW}========================================${COLOR_RESET}"
echo ""
echo "以下の項目を目視で確認してください："
echo ""
echo "1. カラー出力"
echo "   - 成功メッセージが緑色の✓アイコンで表示される"
echo "   - エラーメッセージが赤色の✗アイコンで表示される"
echo "   - --no-color使用時は色が表示されない"
echo ""
echo "2. 設定ファイル"
echo "   - BM_CONFIG指定で設定が読み込まれる"
echo "   - COLOR_ENABLED=false でカラーが無効化される"
echo "   - NO_COLOR=1 でカラーが無効化される"
echo ""
echo "3. アイコン"
echo "   - ✓✗ℹ⚠ などのアイコンが正しく表示される"
echo ""

# ========================================
# クリーンアップ
# ========================================

echo ""
read -p "テスト環境をクリーンアップしますか？ (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${COLOR_YELLOW}Phase 2 テスト環境をクリーンアップしています...${COLOR_RESET}"

    # テストデータ削除
    if [ -d "$TEST_DATA_DIR" ]; then
        rm -rf "$TEST_DATA_DIR"
        echo -e "${COLOR_GREEN}✓${COLOR_RESET} テストデータを削除"
    fi

    # 環境変数をクリア
    unset BM_FILE BM_HISTORY BM_CONFIG
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} 環境変数をクリア"

    echo -e "${COLOR_GREEN}クリーンアップ完了！${COLOR_RESET}"
else
    echo ""
    echo "テスト環境は保持されています。"
    echo "手動でクリーンアップする場合："
    echo "  rm -rf $TEST_DATA_DIR"
    echo ""
fi

# 終了コード
if [ $FAIL_COUNT -eq 0 ]; then
    exit 0
else
    exit 1
fi
