#!/usr/bin/env bats

# テスト前の準備
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR=$(mktemp -d)
    export BM_FILE="$TEST_DIR/test_bookmarks"

    # テスト用のプロジェクトディレクトリを作成
    mkdir -p "$TEST_DIR/project1"
    mkdir -p "$TEST_DIR/project2"

    # テスト実行前にbmc.shをPATHに追加
    export PATH="$BATS_TEST_DIRNAME/../cli:$PATH"
}

# テスト後のクリーンアップ
teardown() {
    # テスト用ディレクトリを削除
    [ -n "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

# ヘルプメッセージの表示テスト
@test "bmc without arguments shows help" {
    run bmc
    [ "$status" -eq 0 ]
    [[ "$output" =~ "bmc" ]]
    [[ "$output" =~ "Usage" ]]
}

# ヘルプコマンドのテスト
@test "bmc help shows usage information" {
    run bmc help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "add" ]]
    [[ "$output" =~ "go" ]]
    [[ "$output" =~ "list" ]]
}

# ブックマーク追加のテスト
@test "bmc add creates bookmark with current directory" {
    cd "$TEST_DIR/project1"
    run bmc add test_project
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bookmark 'test_project' added" ]]

    # ブックマークファイルが作成されていることを確認
    [ -f "$BM_FILE" ]

    # ブックマークの内容を確認
    run cat "$BM_FILE"
    [[ "$output" =~ "test_project" ]]
    [[ "$output" =~ "$TEST_DIR/project1" ]]
}

# 指定パスでのブックマーク追加テスト
@test "bmc add creates bookmark with specified path" {
    run bmc add test_project2 "$TEST_DIR/project2"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bookmark 'test_project2' added" ]]

    # ブックマークの内容を確認
    run cat "$BM_FILE"
    [[ "$output" =~ "test_project2" ]]
    [[ "$output" =~ "$TEST_DIR/project2" ]]
}

# 重複するブックマーク名のテスト
@test "bmc add prevents duplicate bookmark names" {
    cd "$TEST_DIR/project1"
    run bmc add duplicate_test
    [ "$status" -eq 0 ]

    # 同じ名前で再度追加を試行
    run bmc add duplicate_test
    [ "$status" -ne 0 ]
    [[ "$output" =~ "already exists" ]]
}

# ブックマーク一覧表示のテスト
@test "bmc list shows bookmarks" {
    # まず2つのブックマークを追加
    bmc add proj1 "$TEST_DIR/project1"
    bmc add proj2 "$TEST_DIR/project2"

    run bmc list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "proj1" ]]
    [[ "$output" =~ "$TEST_DIR/project1" ]]
    [[ "$output" =~ "proj2" ]]
    [[ "$output" =~ "$TEST_DIR/project2" ]]
}

# 空のブックマーク一覧のテスト
@test "bmc list shows message when no bookmarks exist" {
    run bmc list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No bookmarks" ]]
}

# 存在しないブックマークへのアクセステスト
@test "bmc go fails for non-existent bookmark" {
    run bmc go nonexistent
    [ "$status" -ne 0 ]
    [[ "$output" =~ "not found" ]]
}

# ブックマークファイルが存在しない場合のテスト
@test "commands handle missing bookmark file gracefully" {
    export BM_FILE="$TEST_DIR/nonexistent_bookmarks"

    run bmc list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No bookmarks" ]]
}

# 不正な引数のテスト
@test "bmc add fails without bookmark name" {
    run bmc add
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Usage" ]]
}

# 存在しないパスでのブックマーク追加テスト
@test "bmc add fails with non-existent path" {
    run bmc add test_invalid "/nonexistent/path"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "does not exist" ]]
}