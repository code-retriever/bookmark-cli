#!/usr/bin/env bats

# ブックマーク検証機能のテスト

# テスト前の準備
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR=$(mktemp -d)
    export BM_FILE="$TEST_DIR/test_bookmarks"

    # テスト用のプロジェクトディレクトリを作成
    mkdir -p "$TEST_DIR/valid_project1"
    mkdir -p "$TEST_DIR/valid_project2"

    # テスト実行前にbmc.shをPATHに追加
    export PATH="$BATS_TEST_DIRNAME/../cli:$PATH"

    # テスト用のブックマークを事前に作成（有効と無効の両方）
    echo "valid1:$TEST_DIR/valid_project1" > "$BM_FILE"
    echo "valid2:$TEST_DIR/valid_project2" >> "$BM_FILE"
    echo "invalid1:$TEST_DIR/nonexistent_dir1" >> "$BM_FILE"
    echo "invalid2:/totally/fake/path" >> "$BM_FILE"
}

# テスト後のクリーンアップ
teardown() {
    # テスト用ディレクトリを削除
    [ -n "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

# === VALIDATE コマンドのテスト ===

# 全ブックマークが有効な場合のテスト
@test "bmc validate reports all bookmarks are valid" {
    # 無効なブックマークを削除して有効なものだけにする
    echo "valid1:$TEST_DIR/valid_project1" > "$BM_FILE"
    echo "valid2:$TEST_DIR/valid_project2" >> "$BM_FILE"

    run bmc validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "All bookmarks are valid" || "$output" =~ "valid" ]]
}

# 無効なブックマークがある場合のテスト
@test "bmc validate detects invalid bookmarks" {
    run bmc validate
    [ "$status" -ne 0 ]
    [[ "$output" =~ "invalid" || "$output" =~ "not found" || "$output" =~ "Invalid" ]]
    [[ "$output" =~ "invalid1" || "$output" =~ "nonexistent_dir1" ]]
}

# 無効なブックマークの数を正しくカウント
@test "bmc validate counts invalid bookmarks correctly" {
    run bmc validate
    [ "$status" -ne 0 ]
    # 2つの無効なブックマークがあることを確認
    [[ "$output" =~ "2" ]]
}

# 空のブックマークファイルの場合
@test "bmc validate handles empty bookmarks file" {
    export BM_FILE="$TEST_DIR/empty_bookmarks"
    touch "$BM_FILE"

    run bmc validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No bookmarks" || "$output" =~ "empty" ]]
}

# ブックマークファイルが存在しない場合
@test "bmc validate handles missing bookmarks file" {
    export BM_FILE="$TEST_DIR/nonexistent_bookmarks"

    run bmc validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No bookmarks" || "$output" =~ "not found" ]]
}

# === CLEAN コマンドのテスト ===

# 無効なブックマークを削除
@test "bmc clean removes invalid bookmarks" {
    run bmc clean
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Removed" || "$output" =~ "Cleaned" ]]

    # ブックマークファイルに無効なものが残っていないことを確認
    run cat "$BM_FILE"
    [[ ! "$output" =~ "invalid1" ]]
    [[ ! "$output" =~ "invalid2" ]]
    [[ "$output" =~ "valid1" ]]
    [[ "$output" =~ "valid2" ]]
}

# 削除した数を報告
@test "bmc clean reports number of removed bookmarks" {
    run bmc clean
    [ "$status" -eq 0 ]
    [[ "$output" =~ "2" ]]
}

# 全て有効な場合は何も削除しない
@test "bmc clean does nothing when all bookmarks are valid" {
    echo "valid1:$TEST_DIR/valid_project1" > "$BM_FILE"
    echo "valid2:$TEST_DIR/valid_project2" >> "$BM_FILE"

    run bmc clean
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No invalid" || "$output" =~ "All bookmarks are valid" || "$output" =~ "0" ]]
}

# ドライランオプション
@test "bmc clean --dry-run shows what would be removed" {
    run bmc clean --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would remove" || "$output" =~ "dry" ]]

    # ファイルが変更されていないことを確認
    run grep "invalid1" "$BM_FILE"
    [ "$status" -eq 0 ]
}

# === DOCTOR コマンドのテスト ===

# 診断結果の表示
@test "bmc doctor shows diagnostic information" {
    run bmc doctor
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Diagnostic" || "$output" =~ "診断" || "$output" =~ "Health" ]]
}

# 無効なブックマークをリスト表示
@test "bmc doctor lists invalid bookmarks with details" {
    run bmc doctor
    [ "$status" -eq 0 ]
    [[ "$output" =~ "invalid1" || "$output" =~ "nonexistent_dir1" ]]
    [[ "$output" =~ "invalid2" || "$output" =~ "totally/fake/path" ]]
}

# 統計情報を表示
@test "bmc doctor shows statistics" {
    run bmc doctor
    [ "$status" -eq 0 ]
    # 総数、有効数、無効数
    [[ "$output" =~ "Total" || "$output" =~ "合計" ]]
    [[ "$output" =~ "Valid" || "$output" =~ "有効" ]]
    [[ "$output" =~ "Invalid" || "$output" =~ "無効" ]]
}

# 全て有効な場合のdoctor
@test "bmc doctor shows healthy status when all valid" {
    echo "valid1:$TEST_DIR/valid_project1" > "$BM_FILE"
    echo "valid2:$TEST_DIR/valid_project2" >> "$BM_FILE"

    run bmc doctor
    [ "$status" -eq 0 ]
    [[ "$output" =~ "healthy" || "$output" =~ "OK" || "$output" =~ "✓" || "$output" =~ "All bookmarks are valid" ]]
}

# エイリアスのテスト
@test "bmc check works as alias for bmc validate" {
    run bmc check
    [ "$status" -ne 0 ]
    [[ "$output" =~ "invalid" || "$output" =~ "not found" || "$output" =~ "Invalid" ]]
}
