#!/usr/bin/env bats

# テスト前の準備
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR=$(mktemp -d)
    export BM_FILE="$TEST_DIR/test_bookmarks"

    # テスト用のプロジェクトディレクトリを作成
    mkdir -p "$TEST_DIR/project1"
    mkdir -p "$TEST_DIR/project2"
    mkdir -p "$TEST_DIR/project3"

    # テスト実行前にbmc.shをPATHに追加
    export PATH="$BATS_TEST_DIRNAME/../cli:$PATH"

    # テスト用のブックマークを事前に作成
    echo "proj1:$TEST_DIR/project1" > "$BM_FILE"
    echo "proj2:$TEST_DIR/project2" >> "$BM_FILE"
    echo "proj3:$TEST_DIR/project3" >> "$BM_FILE"
}

# テスト後のクリーンアップ
teardown() {
    # テスト用ディレクトリを削除
    [ -n "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

# === RENAME コマンドのテスト ===

# ブックマーク名前変更の基本テスト
@test "bmc rename changes bookmark name successfully" {
    run bmc rename proj1 project_one
    [ "$status" -eq 0 ]
    [[ "$output" =~ "renamed" ]]

    # 古い名前が存在しないことを確認
    run bmc go proj1
    [ "$status" -ne 0 ]

    # 新しい名前で移動できることを確認
    run bmc go project_one
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$TEST_DIR/project1" ]]
}

# 存在しないブックマークのリネームテスト
@test "bmc rename fails for non-existent bookmark" {
    run bmc rename nonexistent new_name
    [ "$status" -ne 0 ]
    [[ "$output" =~ "not found" ]]
}

# 既存の名前へのリネームテスト（重複チェック）
@test "bmc rename fails when target name already exists" {
    run bmc rename proj1 proj2
    [ "$status" -ne 0 ]
    [[ "$output" =~ "already exists" ]]
}

# 引数不足のテスト
@test "bmc rename fails without sufficient arguments" {
    run bmc rename proj1
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Usage" ]]

    run bmc rename
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Usage" ]]
}

# mvエイリアスのテスト
@test "bmc mv works as alias for bmc rename" {
    run bmc mv proj2 project_two
    [ "$status" -eq 0 ]
    [[ "$output" =~ "renamed" ]]

    run bmc go project_two
    [ "$status" -eq 0 ]
}

# === EXPORT コマンドのテスト ===

# 標準出力へのエクスポートテスト
@test "bmc export outputs bookmarks to stdout" {
    run bmc export
    [ "$status" -eq 0 ]
    [[ "$output" =~ "proj1" ]]
    [[ "$output" =~ "proj2" ]]
    [[ "$output" =~ "proj3" ]]
    [[ "$output" =~ "$TEST_DIR/project1" ]]
}

# ファイルへのエクスポートテスト
@test "bmc export saves bookmarks to file" {
    local export_file="$TEST_DIR/exported_bookmarks.json"

    run bmc export "$export_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Exported" ]]

    # エクスポートファイルが作成されていることを確認
    [ -f "$export_file" ]

    # JSON形式で出力されていることを確認
    run cat "$export_file"
    [[ "$output" =~ "proj1" ]]
    [[ "$output" =~ "proj2" ]]
}

# 空のブックマークのエクスポートテスト
@test "bmc export handles empty bookmarks gracefully" {
    export BM_FILE="$TEST_DIR/empty_bookmarks"

    run bmc export
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No bookmarks" || "$output" =~ "\[\]" || "$output" =~ "[]" ]]
}

# expエイリアスのテスト
@test "bmc exp works as alias for bmc export" {
    run bmc exp
    [ "$status" -eq 0 ]
    [[ "$output" =~ "proj1" ]]
}

# === IMPORT コマンドのテスト ===

# JSONファイルからのインポートテスト
@test "bmc import loads bookmarks from JSON file" {
    # エクスポートファイルを作成
    local import_file="$TEST_DIR/import_bookmarks.json"
    cat > "$import_file" << EOF
[
  {
    "name": "imported1",
    "path": "$TEST_DIR/project1"
  },
  {
    "name": "imported2",
    "path": "$TEST_DIR/project2"
  }
]
EOF

    # 空のブックマークファイルでテスト
    export BM_FILE="$TEST_DIR/new_bookmarks"

    run bmc import "$import_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Imported" ]]

    # インポートされたブックマークが使用できることを確認
    run bmc go imported1
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$TEST_DIR/project1" ]]
}

# 単純な形式からのインポートテスト
@test "bmc import supports simple name:path format" {
    local import_file="$TEST_DIR/simple_import.txt"
    cat > "$import_file" << EOF
simple1:$TEST_DIR/project1
simple2:$TEST_DIR/project2
EOF

    export BM_FILE="$TEST_DIR/simple_bookmarks"

    run bmc import "$import_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Imported" ]]

    run bmc list
    [[ "$output" =~ "simple1" ]]
    [[ "$output" =~ "simple2" ]]
}

# 存在しないファイルのインポートテスト
@test "bmc import fails for non-existent file" {
    run bmc import "/nonexistent/file.json"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "not found" || "$output" =~ "does not exist" ]]
}

# 無効なJSONファイルのインポートテスト
@test "bmc import handles invalid JSON gracefully" {
    local invalid_file="$TEST_DIR/invalid.json"
    echo "[{invalid json content}]" > "$invalid_file"

    run bmc import "$invalid_file"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "invalid" || "$output" =~ "error" || "$output" =~ "Invalid" || "$output" =~ "Error" ]]
}

# impエイリアスのテスト
@test "bmc imp works as alias for bmc import" {
    local import_file="$TEST_DIR/alias_test.txt"
    echo "alias_test:$TEST_DIR/project1" > "$import_file"

    export BM_FILE="$TEST_DIR/alias_bookmarks"

    run bmc imp "$import_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Imported" ]]
}

# 重複するブックマークのインポートテスト
@test "bmc import handles duplicate bookmarks" {
    local import_file="$TEST_DIR/duplicate_import.txt"
    echo "proj1:$TEST_DIR/project1" > "$import_file"

    run bmc import "$import_file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "skipped" || "$output" =~ "already exists" || "$output" =~ "Skipped" ]]
}

# 引数不足のテスト
@test "bmc import fails without file argument" {
    run bmc import
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Usage" ]]
}

# === 統合テスト ===

# エクスポート→インポートのワークフローテスト
@test "export and import workflow works correctly" {
    local backup_file="$TEST_DIR/backup.json"

    # エクスポート
    run bmc export "$backup_file"
    [ "$status" -eq 0 ]

    # 新しいブックマークファイル
    export BM_FILE="$TEST_DIR/restored_bookmarks"

    # インポート
    run bmc import "$backup_file"
    [ "$status" -eq 0 ]

    # すべてのブックマークが復元されていることを確認
    run bmc list
    [[ "$output" =~ "proj1" ]]
    [[ "$output" =~ "proj2" ]]
    [[ "$output" =~ "proj3" ]]
}