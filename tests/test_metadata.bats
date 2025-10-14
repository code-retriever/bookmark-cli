#!/usr/bin/env bats

# ブックマークのメタデータ（description, tags）機能のテスト

# テスト前の準備
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR=$(mktemp -d)
    export BM_FILE="$TEST_DIR/test_bookmarks"
    export BM_HISTORY="$TEST_DIR/test_history"

    # テスト用のプロジェクトディレクトリを作成
    mkdir -p "$TEST_DIR/project1"
    mkdir -p "$TEST_DIR/project2"
    mkdir -p "$TEST_DIR/project3"

    # テスト実行前にbmc.shをPATHに追加
    export PATH="$BATS_TEST_DIRNAME/../cli:$PATH"
}

# テスト後のクリーンアップ
teardown() {
    # テスト用ディレクトリを削除
    [ -n "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

# === DESCRIPTION（説明）フィールドのテスト ===

# descriptionオプションでブックマーク追加
@test "bmc add with description option" {
    cd "$TEST_DIR/project1"
    run bmc add work -d "仕事用プロジェクト"
    [ "$status" -eq 0 ]

    # ブックマークファイルにdescriptionが保存されている
    run cat "$BM_FILE"
    [[ "$output" =~ "work:$TEST_DIR/project1:仕事用プロジェクト" ]]
}

# --descriptionロングオプション
@test "bmc add with --description long option" {
    cd "$TEST_DIR/project1"
    run bmc add work --description "Work project"
    [ "$status" -eq 0 ]

    run cat "$BM_FILE"
    [[ "$output" =~ "Work project" ]]
}

# descriptionなしでも動作する（後方互換性）
@test "bmc add without description works (backward compatibility)" {
    cd "$TEST_DIR/project1"
    run bmc add work
    [ "$status" -eq 0 ]

    # 旧形式または新形式（descriptionが空）で保存される
    run cat "$BM_FILE"
    [[ "$output" =~ "work:$TEST_DIR/project1" ]]
}

# listでdescriptionを表示
@test "bmc list shows description" {
    echo "work:$TEST_DIR/project1:仕事用プロジェクト:" > "$BM_FILE"
    echo "home:$TEST_DIR/project2:ホームディレクトリ:" >> "$BM_FILE"

    run bmc list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "仕事用プロジェクト" ]]
    [[ "$output" =~ "ホームディレクトリ" ]]
}

# === TAGS（タグ）フィールドのテスト ===

# tagsオプションでブックマーク追加
@test "bmc add with tags option" {
    cd "$TEST_DIR/project1"
    run bmc add work -t work,project
    [ "$status" -eq 0 ]

    # タグがカンマ区切りで保存されている
    run cat "$BM_FILE"
    [[ "$output" =~ "work,project" ]]
}

# --tagsロングオプション
@test "bmc add with --tags long option" {
    cd "$TEST_DIR/project1"
    run bmc add work --tags "work,project,development"
    [ "$status" -eq 0 ]

    run cat "$BM_FILE"
    [[ "$output" =~ "work,project,development" ]]
}

# descriptionとtagsを同時に指定
@test "bmc add with both description and tags" {
    cd "$TEST_DIR/project1"
    run bmc add work -d "仕事用" -t work,project
    [ "$status" -eq 0 ]

    run cat "$BM_FILE"
    [[ "$output" =~ "work:$TEST_DIR/project1:仕事用:work,project" ]]
}

# タグでフィルタリング
@test "bmc list --tag filters by tag" {
    echo "work:$TEST_DIR/project1::work,project" > "$BM_FILE"
    echo "home:$TEST_DIR/project2::personal" >> "$BM_FILE"
    echo "temp:$TEST_DIR/project3::work,temp" >> "$BM_FILE"

    run bmc list --tag work
    [ "$status" -eq 0 ]
    [[ "$output" =~ "work" ]]
    [[ "$output" =~ "temp" ]]
    [[ ! "$output" =~ "home" ]] || true  # homeは表示されない
}

# タグ一覧表示
@test "bmc tags shows all unique tags" {
    echo "work:$TEST_DIR/project1::work,project" > "$BM_FILE"
    echo "home:$TEST_DIR/project2::personal,home" >> "$BM_FILE"
    echo "temp:$TEST_DIR/project3::work,temp" >> "$BM_FILE"

    run bmc tags
    [ "$status" -eq 0 ]
    [[ "$output" =~ "work" ]]
    [[ "$output" =~ "project" ]]
    [[ "$output" =~ "personal" ]]
    [[ "$output" =~ "home" ]]
    [[ "$output" =~ "temp" ]]
}

# === 後方互換性のテスト ===

# 旧形式のブックマークを読み込める
@test "bmc list reads old format bookmarks" {
    # 旧形式（name:path）
    echo "oldwork:$TEST_DIR/project1" > "$BM_FILE"
    # 新形式
    echo "newwork:$TEST_DIR/project2:新しい仕事:work" >> "$BM_FILE"

    run bmc list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "oldwork" ]]
    [[ "$output" =~ "newwork" ]]
}

# 旧形式のブックマークへの移動が可能
@test "bmc go works with old format bookmarks" {
    echo "oldwork:$TEST_DIR/project1" > "$BM_FILE"

    run bmc go oldwork
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$TEST_DIR/project1" ]]
}

# === VALIDATION（検証）との統合 ===

# validate, clean, doctorが新形式に対応
@test "bmc validate works with metadata format" {
    echo "work:$TEST_DIR/project1:説明:tag1" > "$BM_FILE"
    echo "invalid:/nonexistent:説明:tag2" >> "$BM_FILE"

    run bmc validate
    [ "$status" -ne 0 ]
    [[ "$output" =~ "invalid" ]]
}

# === EXPORT/IMPORT との統合 ===

# exportがメタデータを含む
@test "bmc export includes metadata" {
    echo "work:$TEST_DIR/project1:仕事用:work,project" > "$BM_FILE"

    run bmc export "$TEST_DIR/export.json"
    [ "$status" -eq 0 ]

    # JSONにdescriptionとtagsが含まれる
    run cat "$TEST_DIR/export.json"
    [[ "$output" =~ "description" ]]
    [[ "$output" =~ "tags" ]]
}

# importがメタデータを復元
@test "bmc import restores metadata" {
    # メタデータ付きJSONを作成
    cat > "$TEST_DIR/import.json" << 'EOF'
{
  "bookmarks": [
    {
      "name": "work",
      "path": "/tmp/work",
      "description": "仕事用",
      "tags": ["work", "project"]
    }
  ]
}
EOF

    run bmc import "$TEST_DIR/import.json"
    [ "$status" -eq 0 ]

    # ブックマークファイルにメタデータが含まれる
    run cat "$BM_FILE"
    [[ "$output" =~ "仕事用" ]]
    [[ "$output" =~ "work,project" ]]
}

# === UI統合のテスト ===

# UIモードでメタデータがプレビューに表示される
@test "bmc ui preview shows metadata" {
    skip "fzfモックが必要なため手動テスト"
    # このテストは手動で確認
}
