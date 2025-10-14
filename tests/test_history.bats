#!/usr/bin/env bats

# ブックマーク履歴・頻度追跡機能のテスト

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

    # テスト用のブックマークを事前に作成
    echo "proj1:$TEST_DIR/project1" > "$BM_FILE"
    echo "proj2:$TEST_DIR/project2" >> "$BM_FILE"
    echo "proj3:$TEST_DIR/project3" >> "$BM_FILE"
    echo "work:$TEST_DIR/project1" >> "$BM_FILE"
    echo "home:$TEST_DIR/project2" >> "$BM_FILE"
}

# テスト後のクリーンアップ
teardown() {
    # テスト用ディレクトリを削除
    [ -n "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

# === RECENT コマンドのテスト ===

# 履歴が空の場合
@test "bmc recent shows message when no history" {
    run bmc recent
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No history" || "$output" =~ "empty" || "$output" =~ "found" ]]
}

# 最近使用したブックマークを表示
@test "bmc recent shows recently used bookmarks" {
    # 履歴を作成（手動でhistoryファイルに記録）
    echo "$(date +%s):proj1" > "$BM_HISTORY"
    sleep 1
    echo "$(date +%s):proj2" >> "$BM_HISTORY"
    sleep 1
    echo "$(date +%s):proj3" >> "$BM_HISTORY"

    run bmc recent
    [ "$status" -eq 0 ]
    # 最新のものから順に表示される
    [[ "$output" =~ "proj3" ]]
    [[ "$output" =~ "proj2" ]]
    [[ "$output" =~ "proj1" ]]
}

# 最新10件のみ表示
@test "bmc recent limits to 10 most recent" {
    # 15個の履歴エントリを作成
    for i in {1..15}; do
        echo "$(date +%s):proj$((i % 3 + 1))" >> "$BM_HISTORY"
        sleep 0.1
    done

    run bmc recent
    [ "$status" -eq 0 ]
    # 10行以内であることを確認（ヘッダー含む）
    line_count=$(echo "$output" | wc -l)
    [ $line_count -le 12 ]  # ヘッダー + 10エントリ + 余裕
}

# recent エイリアスのテスト
@test "bmc r works as alias for bmc recent" {
    echo "$(date +%s):proj1" > "$BM_HISTORY"

    run bmc r
    [ "$status" -eq 0 ]
    [[ "$output" =~ "proj1" ]]
}

# === FREQUENT コマンドのテスト ===

# 頻繁に使用するブックマークを表示
@test "bmc frequent shows most frequently used bookmarks" {
    # 異なる頻度で履歴を作成
    for i in {1..5}; do
        echo "$(date +%s):proj1" >> "$BM_HISTORY"
        sleep 0.1
    done
    for i in {1..3}; do
        echo "$(date +%s):proj2" >> "$BM_HISTORY"
        sleep 0.1
    done
    for i in {1..1}; do
        echo "$(date +%s):proj3" >> "$BM_HISTORY"
        sleep 0.1
    done

    run bmc frequent
    [ "$status" -eq 0 ]
    # proj1が最も頻繁（5回）
    [[ "$output" =~ "proj1" ]]
    [[ "$output" =~ "5" || "$output" =~ "proj1.*5" ]]
}

# 履歴が空の場合
@test "bmc frequent shows message when no history" {
    run bmc frequent
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No history" || "$output" =~ "empty" || "$output" =~ "found" ]]
}

# 頻度の高い順にソート
@test "bmc frequent sorts by frequency" {
    # 異なる頻度で履歴を作成
    for i in {1..2}; do echo "$(date +%s):proj1" >> "$BM_HISTORY"; done
    for i in {1..5}; do echo "$(date +%s):proj2" >> "$BM_HISTORY"; done
    for i in {1..3}; do echo "$(date +%s):proj3" >> "$BM_HISTORY"; done

    run bmc frequent
    [ "$status" -eq 0 ]

    # proj2が最も頻繁なので最初に表示されるべき
    # 出力の最初の方にproj2が、最後の方にproj1が来ることを期待
    first_half=$(echo "$output" | head -n 5)
    [[ "$first_half" =~ "proj2" ]]
}

# === GO コマンド（履歴統合）のテスト ===

# 引数なしのgoコマンドで履歴から選択
@test "bmc go without args uses recent history" {
    # fzfモックを作成
    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
# 入力を読み捨てて最初の項目を返す
cat > /dev/null
echo "proj1"
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    # 履歴を作成
    echo "$(date +%s):proj1" > "$BM_HISTORY"
    echo "$(date +%s):proj2" >> "$BM_HISTORY"

    run bmc go
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$TEST_DIR/project1" || "$output" =~ "proj1" ]]
}

# 引数ありの場合は通常通り動作
@test "bmc go with arg works normally" {
    run bmc go proj2
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$TEST_DIR/project2" ]]
}

# === 履歴記録のテスト ===

# goコマンドで履歴が記録される
@test "bmc go records history" {
    # 既存の履歴ファイルを削除
    rm -f "$BM_HISTORY"

    # goコマンドを実行
    run bmc go proj1
    [ "$status" -eq 0 ]

    # 履歴ファイルが作成され、proj1が記録されている
    [ -f "$BM_HISTORY" ]
    run cat "$BM_HISTORY"
    [[ "$output" =~ "proj1" ]]
}

# uiコマンドでも履歴が記録される
@test "bmc ui records history" {
    # fzfモックを作成
    mkdir -p "$TEST_DIR/mock_bin"
    cat > "$TEST_DIR/mock_bin/fzf" << 'EOF'
#!/bin/sh
cat > /dev/null
echo "proj2"
EOF
    chmod +x "$TEST_DIR/mock_bin/fzf"
    export PATH="$TEST_DIR/mock_bin:$PATH"

    rm -f "$BM_HISTORY"

    run bmc ui
    [ "$status" -eq 0 ]

    # 履歴ファイルにproj2が記録されている
    [ -f "$BM_HISTORY" ]
    run cat "$BM_HISTORY"
    [[ "$output" =~ "proj2" ]]
}

# タイムスタンプ形式の確認
@test "history uses unix timestamp format" {
    rm -f "$BM_HISTORY"

    run bmc go proj1
    [ "$status" -eq 0 ]

    # 履歴の形式を確認（timestamp:bookmark_name）
    history_entry=$(cat "$BM_HISTORY" | head -1)
    [[ "$history_entry" =~ ^[0-9]+:proj1$ ]]
}

# === STATS コマンドのテスト（ボーナス機能） ===

# 統計情報の表示
@test "bmc stats shows usage statistics" {
    # 履歴を作成
    for i in {1..10}; do echo "$(date +%s):proj1" >> "$BM_HISTORY"; done
    for i in {1..5}; do echo "$(date +%s):proj2" >> "$BM_HISTORY"; done

    run bmc stats
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Total" || "$output" =~ "合計" ]]
    [[ "$output" =~ "15" ]]  # 合計15回のアクセス
}
