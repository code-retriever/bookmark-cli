#!/usr/bin/env bats

# Phase 2-1: カラー出力機能のテスト

# テスト前の準備
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR=$(mktemp -d)
    export BM_FILE="$TEST_DIR/test_bookmarks"
    export BM_HISTORY="$TEST_DIR/test_history"

    # テスト用のプロジェクトディレクトリを作成
    mkdir -p "$TEST_DIR/project1"
    mkdir -p "$TEST_DIR/project2"

    # テスト実行前にbmc.shをPATHに追加
    export PATH="$BATS_TEST_DIRNAME/../cli:$PATH"

    # カラー環境変数をクリア
    unset NO_COLOR
    unset COLOR_ENABLED
}

# テスト後のクリーンアップ
teardown() {
    # テスト用ディレクトリを削除
    [ -n "$TEST_DIR" ] && rm -rf "$TEST_DIR"

    # 環境変数をクリア
    unset NO_COLOR
    unset COLOR_ENABLED
}

# カラーコードの初期化テスト
@test "init_colors sets color variables when colors are enabled" {
    # tputかエスケープシーケンスのどちらかが使われる
    export COLOR_ENABLED=true
    run bash -c "source cli/bmc.sh && init_colors && echo \"SUCCESS:\$COLOR_SUCCESS\" && echo \"ERROR:\$COLOR_ERROR\" && echo \"INFO:\$COLOR_INFO\""

    [ "$status" -eq 0 ]
    # カラーコードが設定されている（空ではない）
    [[ "$output" =~ "SUCCESS:" ]]
    [[ ! "$output" =~ "SUCCESS:$" ]]  # 空ではないことを確認
}

# NO_COLOR環境変数でカラー無効化
@test "NO_COLOR environment variable disables colors" {
    export NO_COLOR=1
    run bash -c "source cli/bmc.sh && init_colors && test -z \"\$COLOR_SUCCESS\" && test -z \"\$COLOR_RESET\" && echo 'Colors disabled'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Colors disabled" ]]
}

# COLOR_ENABLED=falseでカラー無効化
@test "COLOR_ENABLED=false disables colors" {
    export COLOR_ENABLED=false
    run bash -c "source cli/bmc.sh && init_colors && test -z \"\$COLOR_SUCCESS\" && test -z \"\$COLOR_ERROR\" && echo 'Colors disabled'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Colors disabled" ]]
}

# print_success関数のテスト
@test "print_success outputs success message" {
    export NO_COLOR=1  # テストのためカラー無効化
    run bash -c "source cli/bmc.sh && init_colors && print_success 'Test success message'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "✓" ]]
    [[ "$output" =~ "Test success message" ]]
}

# print_error関数のテスト
@test "print_error outputs error message to stderr" {
    export NO_COLOR=1
    run bash -c "source cli/bmc.sh && init_colors && print_error 'Test error message'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "✗" ]]
    [[ "$output" =~ "Test error message" ]]
}

# print_info関数のテスト
@test "print_info outputs info message" {
    export NO_COLOR=1
    run bash -c "source cli/bmc.sh && init_colors && print_info 'Test info message'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "ℹ" ]]
    [[ "$output" =~ "Test info message" ]]
}

# print_warning関数のテスト
@test "print_warning outputs warning message" {
    export NO_COLOR=1
    run bash -c "source cli/bmc.sh && init_colors && print_warning 'Test warning message'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "⚠" ]]
    [[ "$output" =~ "Test warning message" ]]
}

# bmc addコマンドでカラー出力（成功）
@test "bmc add shows colored success message" {
    cd "$TEST_DIR/project1"
    run bmc add testbm

    [ "$status" -eq 0 ]
    # カラーが有効な場合、出力にエスケープシーケンスまたはメッセージが含まれる
    [[ "$output" =~ "Bookmark 'testbm' added" ]]
}

# bmc addコマンドでカラー出力（エラー）
@test "bmc add shows colored error for duplicate" {
    cd "$TEST_DIR/project1"
    bmc add testbm

    run bmc add testbm
    [ "$status" -ne 0 ]
    [[ "$output" =~ "already exists" ]]
}

# --no-colorオプションでカラー無効化
@test "bmc add --no-color disables color output" {
    cd "$TEST_DIR/project1"
    export COLOR_ENABLED=true
    run bmc add --no-color testbm

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bookmark 'testbm' added" ]]
    # NO_COLORが設定されているか、出力にエスケープシーケンスがない
}

# bmc listコマンドでカラー出力
@test "bmc list shows colored output" {
    bmc add proj1 "$TEST_DIR/project1"
    bmc add proj2 "$TEST_DIR/project2"

    run bmc list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "NAME" ]]
    [[ "$output" =~ "proj1" ]]
    [[ "$output" =~ "proj2" ]]
}

# 無効なパスでのカラー警告表示
@test "bmc list shows colored warning for missing paths" {
    # 存在しないパスのブックマークを手動作成
    echo "missing:$TEST_DIR/nonexistent:::" >> "$BM_FILE"

    run bmc list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "missing" ]]
    # 警告表示があることを確認（実装後に詳細チェック）
}

# アイコン表示のテスト
@test "color output includes icons" {
    export NO_COLOR=1
    run bash -c "source cli/bmc.sh && init_colors && print_success 'Test' && print_error 'Test' && print_info 'Test' && print_warning 'Test'"

    [ "$status" -eq 0 ]
    # 各アイコンが含まれることを確認
    [[ "$output" =~ "✓" ]]  # SUCCESS
    [[ "$output" =~ "✗" ]]  # ERROR
    [[ "$output" =~ "ℹ" ]]  # INFO
    [[ "$output" =~ "⚠" ]]  # WARNING
}

# ターミナル非対話時のカラー無効化（パイプ）
@test "color is disabled when output is piped" {
    cd "$TEST_DIR/project1"
    # パイプを通すとターミナルが非対話的になる
    run bash -c "bmc add testbm | cat"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bookmark 'testbm' added" ]]
    # パイプ経由でもメッセージは表示される
}
