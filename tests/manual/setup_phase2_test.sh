#!/bin/bash

# Phase 2-1 & 2-2 手動テスト環境セットアップスクリプト
# 使い方: source tests/manual/setup_phase2_test.sh
#
# 注意:
#  - このスクリプトは **source** コマンドで実行してください（bash ./xxx ではない）
#  - sourceで実行することで、エイリアスと環境変数が現在のシェルに設定されます
#  - 自動テスト（run_phase2_tests.sh）は独立して動作するため、このスクリプトを必要としません
#
# 手動テスト専用:
#  このスクリプトは対話的なテストセッション用です。エイリアス（bmc-test, test-proj-a等）を
#  使って各コマンドを手動で実行し、カラー出力や動作を目視確認できます。

# カラー出力
COLOR_GREEN="\033[0;32m"
COLOR_BLUE="\033[0;34m"
COLOR_YELLOW="\033[0;33m"
COLOR_RESET="\033[0m"

echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Phase 2 テスト環境セットアップ${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""

# プロジェクトルートディレクトリの検出
if [ -f "cli/bmc.sh" ]; then
    PROJECT_ROOT="$(pwd)"
elif [ -f "../cli/bmc.sh" ]; then
    PROJECT_ROOT="$(cd .. && pwd)"
elif [ -f "../../cli/bmc.sh" ]; then
    PROJECT_ROOT="$(cd ../.. && pwd)"
else
    echo -e "${COLOR_YELLOW}警告: プロジェクトルートが見つかりません${COLOR_RESET}"
    echo "cli/bmc.sh があるディレクトリから実行してください"
    return 1 2>/dev/null || exit 1
fi

cd "$PROJECT_ROOT" || exit 1

echo -e "${COLOR_GREEN}✓${COLOR_RESET} プロジェクトルート: $PROJECT_ROOT"

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

cat > "$TEST_DATA_DIR/config_with_spaces" <<'EOF'
CUSTOM_MESSAGE=Hello World With Spaces
QUOTED_VALUE="value with spaces"
SINGLE_QUOTED='another value'
EOF

echo -e "${COLOR_GREEN}✓${COLOR_RESET} 設定ファイルを作成"

# XDG設定ディレクトリ
XDG_TEST_DIR="$TEST_DATA_DIR/xdg_config"
mkdir -p "$XDG_TEST_DIR/bookmark-cli"

cat > "$XDG_TEST_DIR/bookmark-cli/config" <<'EOF'
# XDG Base Directory configuration
COLOR_ENABLED=true
XDG_TEST=true
EOF

echo -e "${COLOR_GREEN}✓${COLOR_RESET} XDG設定ディレクトリを作成"

# ~/.config/bookmark-cli テスト用
HOME_TEST_DIR="$TEST_DATA_DIR/home"
mkdir -p "$HOME_TEST_DIR/.config/bookmark-cli"

cat > "$HOME_TEST_DIR/.config/bookmark-cli/config" <<'EOF'
# Home directory configuration
COLOR_ENABLED=false
HOME_CONFIG_TEST=true
EOF

echo -e "${COLOR_GREEN}✓${COLOR_RESET} HOME設定ディレクトリを作成"

# 環境変数を設定
export BM_FILE="$TEST_DATA_DIR/bookmarks"
export BM_HISTORY="$TEST_DATA_DIR/history"
export BM_CONFIG="$TEST_DATA_DIR/config_color_enabled"

echo ""
echo -e "${COLOR_BLUE}環境変数を設定:${COLOR_RESET}"
echo "  BM_FILE=$BM_FILE"
echo "  BM_HISTORY=$BM_HISTORY"
echo "  BM_CONFIG=$BM_CONFIG"

# エイリアスを作成
alias bmc-test="$PROJECT_ROOT/cli/bmc.sh"
alias bmc-cd='cd $(bmc-test go "$1" 2>/dev/null)'

echo ""
echo -e "${COLOR_BLUE}エイリアスを作成:${COLOR_RESET}"
echo "  bmc-test  : Phase 2テスト用bmcコマンド"
echo "  bmc-cd    : ブックマークへ移動 (例: bmc-cd proj-a)"

# テストプロジェクトへのショートカット
alias test-proj-a="cd $TEST_PROJECTS_DIR/proj-a"
alias test-proj-b="cd $TEST_PROJECTS_DIR/proj-b"
alias test-proj-c="cd $TEST_PROJECTS_DIR/proj-c"
alias test-proj-d="cd $TEST_PROJECTS_DIR/proj-d"

echo "  test-proj-a, b, c, d : テストプロジェクトへ移動"

# クリーンアップ関数を定義
cleanup_phase2_test() {
    echo ""
    echo -e "${COLOR_YELLOW}Phase 2 テスト環境をクリーンアップしています...${COLOR_RESET}"

    # テストデータ削除
    if [ -d "$TEST_DATA_DIR" ]; then
        rm -rf "$TEST_DATA_DIR"
        echo -e "${COLOR_GREEN}✓${COLOR_RESET} テストデータを削除"
    fi

    # 環境変数をクリア
    unset BM_FILE BM_HISTORY BM_CONFIG XDG_CONFIG_HOME
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} 環境変数をクリア"

    # エイリアスを削除
    unalias bmc-test bmc-cd 2>/dev/null
    unalias test-proj-a test-proj-b test-proj-c test-proj-d 2>/dev/null
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} エイリアスを削除"

    # 関数自身も削除
    unset -f cleanup_phase2_test 2>/dev/null
    unset -f show_phase2_help 2>/dev/null

    echo -e "${COLOR_GREEN}クリーンアップ完了！${COLOR_RESET}"
}

# ヘルプ関数を定義
show_phase2_help() {
    cat << 'EOF'

========================================
Phase 2 テストコマンド一覧
========================================

【基本コマンド】
  bmc-test add <name> [path]     ブックマーク追加
  bmc-test list                  一覧表示
  bmc-test go <name>             パス取得
  bmc-test remove <name>         削除
  bmc-test export <file>         エクスポート
  bmc-test import <file>         インポート

【Phase 2-1: カラー出力テスト】
  bmc-test add test1             # 緑色✓アイコン確認
  bmc-test add test1             # 赤色✗エラー確認
  bmc-test --no-color add test2  # カラー無効確認
  NO_COLOR=1 bmc-test list       # NO_COLOR確認
  bmc-test list | cat            # パイプでカラー無効確認

【Phase 2-2: 設定ファイルテスト】
  # 設定ファイル切り替え
  export BM_CONFIG="$TEST_DATA_DIR/config_color_disabled"
  bmc-test add test3             # カラー無効確認

  export BM_CONFIG="$TEST_DATA_DIR/config_color_enabled"
  bmc-test list                  # カラー有効確認

  # XDGテスト
  export BM_CONFIG=""
  export XDG_CONFIG_HOME="$XDG_TEST_DIR"
  bmc-test add test4             # XDG設定読み込み確認

【設定ファイル一覧】
  $TEST_DATA_DIR/config_color_enabled    # カラー有効
  $TEST_DATA_DIR/config_color_disabled   # カラー無効
  $TEST_DATA_DIR/config_no_color         # NO_COLOR=1
  $TEST_DATA_DIR/config_with_comments    # コメント付き
  $TEST_DATA_DIR/config_with_spaces      # スペース含む値

【便利なエイリアス】
  test-proj-a                    # proj-aへ移動
  test-proj-b                    # proj-bへ移動
  test-proj-c                    # proj-cへ移動
  test-proj-d                    # proj-dへ移動

【環境変数】
  BM_FILE     : $BM_FILE
  BM_HISTORY  : $BM_HISTORY
  BM_CONFIG   : $BM_CONFIG

【管理コマンド】
  show_phase2_help               # このヘルプを表示
  cleanup_phase2_test            # テスト環境をクリーンアップ

========================================
EOF
}

echo ""
echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}セットアップ完了！${COLOR_RESET}"
echo -e "${COLOR_GREEN}========================================${COLOR_RESET}"
echo ""
echo "テストを開始するには:"
echo "  show_phase2_help              # ヘルプ表示"
echo "  test-proj-a                   # テストプロジェクトへ移動"
echo "  bmc-test add proj-a           # ブックマーク追加"
echo ""
echo "テスト終了後:"
echo "  cleanup_phase2_test           # クリーンアップ"
echo ""
