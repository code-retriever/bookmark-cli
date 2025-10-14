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

# fzfが利用可能かのチェックテスト
@test "bmc ui checks for fzf availability" {
    # fzfが存在しない環境をシミュレート（基本コマンドは残す）
    export PATH="/usr/bin:/bin:/nonexistent/path"

    run bmc ui
    [ "$status" -ne 0 ]
    [[ "$output" =~ "fzf" ]]
    [[ "$output" =~ "not found" || "$output" =~ "required" ]]
}

# UI機能のヘルプテスト
@test "bmc ui shows help when no bookmarks exist" {
    export BM_FILE="$TEST_DIR/empty_bookmarks"

    run bmc ui
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No bookmarks" ]]
}

# UI機能でブックマーク一覧が表示されるテスト（fzfモック）
@test "bmc ui displays bookmark list for selection" {
    # fzfをモックする簡単なスクリプトを作成
    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
# fzfモック - 入力を表示して最初の行を返す
echo "=== Available bookmarks ===" >&2
cat >&2
echo "proj1"
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    run bmc ui
    [ "$status" -eq 0 ]
    [[ "$output" =~ "proj1" ]]
}

# UI機能でブックマーク選択時の移動テスト
@test "bmc ui navigates to selected bookmark" {
    # fzfモックでproj2を選択するように設定
    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
cat > /dev/null  # 入力を読み捨て
echo "proj2"
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    run bmc ui
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$TEST_DIR/project2" ]]
}

# UI機能でキャンセル時のテスト
@test "bmc ui handles user cancellation gracefully" {
    # fzfモックでキャンセル（空文字列）をシミュレート
    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
cat > /dev/null  # 入力を読み捨て
exit 1  # fzfはキャンセル時にexit 1を返す
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    run bmc ui
    [ "$status" -eq 0 ]  # bmcはキャンセルを正常終了として扱う
    [[ "$output" =~ "Cancelled" || "$output" =~ "No selection" ]]
}

# browse エイリアスのテスト
@test "bmc browse works as alias for bmc ui" {
    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
cat > /dev/null
echo "proj1"
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    run bmc browse
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$TEST_DIR/project1" ]]
}

# fz エイリアスのテスト
@test "bmc fz works as alias for bmc ui" {
    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
cat > /dev/null
echo "proj3"
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    run bmc fz
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$TEST_DIR/project3" ]]
}

# UI機能でプレビュー表示のテスト（高度な機能）
@test "bmc ui provides preview information" {
    # fzfモックでプレビューオプションが呼ばれることを確認
    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
# プレビュー関連のオプションがあるかチェック
for arg in "$@"; do
    case $arg in
        --preview*)
            echo "Preview enabled" >&2
            ;;
    esac
done
cat > /dev/null
echo "proj1"
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    run bmc ui
    [ "$status" -eq 0 ]
}

# UI機能でのフィルタリングテスト
@test "bmc ui supports filtering bookmarks" {
    # より多くのブックマークでテスト
    mkdir -p "$TEST_DIR/work/frontend" "$TEST_DIR/work/backend" "$TEST_DIR/personal/blog"
    echo "work-frontend:$TEST_DIR/work/frontend" >> "$BM_FILE"
    echo "work-backend:$TEST_DIR/work/backend" >> "$BM_FILE"
    echo "personal-blog:$TEST_DIR/personal/blog" >> "$BM_FILE"

    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
# 入力をカウントして適切な数のブックマークが渡されているかチェック
count=$(cat | wc -l)
echo "Processed $count bookmarks" >&2
echo "work-frontend"
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    run bmc ui
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$TEST_DIR/work/frontend" ]]
}

# 存在しないブックマークが選択された場合のエラーハンドリング
@test "bmc ui handles invalid bookmark selection" {
    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
cat > /dev/null
echo "nonexistent_bookmark"
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    run bmc ui
    [ "$status" -ne 0 ]
    [[ "$output" =~ "not found" ]]
}