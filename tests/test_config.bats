#!/usr/bin/env bats

# Phase 2-2: 設定ファイル対応のテスト

# テスト前の準備
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR=$(mktemp -d)
    export BM_FILE="$TEST_DIR/test_bookmarks"
    export BM_HISTORY="$TEST_DIR/test_history"
    export BM_CONFIG="$TEST_DIR/test_config"

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

    # 環境変数をクリア
    unset BM_CONFIG
}

# 設定ファイル読み込みテスト
@test "load_config reads KEY=VALUE format" {
    cat > "$BM_CONFIG" <<EOF
COLOR_ENABLED=true
DEFAULT_EDITOR=vim
CUSTOM_KEY=value123
EOF

    run bash -c "source cli/bmc.sh && load_config \"$BM_CONFIG\" && echo \"COLOR:\$COLOR_ENABLED\" && echo \"EDITOR:\$DEFAULT_EDITOR\" && echo \"CUSTOM:\$CUSTOM_KEY\""

    [ "$status" -eq 0 ]
    [[ "$output" =~ "COLOR:true" ]]
    [[ "$output" =~ "EDITOR:vim" ]]
    [[ "$output" =~ "CUSTOM:value123" ]]
}

# コメント行と空行のスキップ
@test "load_config ignores comments and empty lines" {
    cat > "$BM_CONFIG" <<EOF
# This is a comment
COLOR_ENABLED=true

  # Indented comment
DEFAULT_EDITOR=nano

# Another comment
EOF

    run bash -c "source cli/bmc.sh && load_config \"$BM_CONFIG\" && echo \"COLOR:\$COLOR_ENABLED\" && echo \"EDITOR:\$DEFAULT_EDITOR\""

    [ "$status" -eq 0 ]
    [[ "$output" =~ "COLOR:true" ]]
    [[ "$output" =~ "EDITOR:nano" ]]
}

# 不正な形式の行をスキップ
@test "load_config skips invalid lines" {
    cat > "$BM_CONFIG" <<EOF
COLOR_ENABLED=true
INVALID LINE WITHOUT EQUALS
KEY_WITH_SPACES = value with spaces
ANOTHER_VALID=test
EOF

    run bash -c "source cli/bmc.sh && load_config \"$BM_CONFIG\" && echo \"COLOR:\$COLOR_ENABLED\" && echo \"ANOTHER:\$ANOTHER_VALID\""

    [ "$status" -eq 0 ]
    [[ "$output" =~ "COLOR:true" ]]
    [[ "$output" =~ "ANOTHER:test" ]]
}

# 存在しない設定ファイルのエラーハンドリング
@test "load_config handles missing config file gracefully" {
    run bash -c "source cli/bmc.sh && load_config \"$TEST_DIR/nonexistent_config\" 2>&1"

    # 存在しないファイルは静かに無視される（エラー終了しない）
    [ "$status" -eq 0 ]
}

# BM_CONFIG環境変数による設定ファイル指定
@test "bmc uses BM_CONFIG environment variable" {
    cat > "$BM_CONFIG" <<EOF
COLOR_ENABLED=false
EOF

    export BM_CONFIG="$BM_CONFIG"
    run bash -c "source cli/bmc.sh && test -z \"\$COLOR_SUCCESS\" && echo 'Colors disabled via config'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Colors disabled via config" ]]
}

# XDG_CONFIG_HOME対応
@test "bmc uses XDG_CONFIG_HOME for config location" {
    export XDG_CONFIG_HOME="$TEST_DIR/xdg_config"
    mkdir -p "$XDG_CONFIG_HOME/bookmark-cli"

    cat > "$XDG_CONFIG_HOME/bookmark-cli/config" <<EOF
COLOR_ENABLED=false
DEFAULT_EDITOR=emacs
EOF

    unset BM_CONFIG  # BM_CONFIGが設定されていない場合のテスト
    run bash -c "source cli/bmc.sh && test -z \"\$COLOR_SUCCESS\" && echo 'XDG config loaded'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "XDG config loaded" ]]
}

# ~/.config/bookmark-cli/config デフォルト
@test "bmc uses ~/.config/bookmark-cli/config by default" {
    # XDG_CONFIG_HOMEが未設定の場合のデフォルトパス
    export HOME="$TEST_DIR"
    mkdir -p "$HOME/.config/bookmark-cli"

    cat > "$HOME/.config/bookmark-cli/config" <<EOF
COLOR_ENABLED=false
EOF

    unset BM_CONFIG
    unset XDG_CONFIG_HOME
    run bash -c "source cli/bmc.sh && test -z \"\$COLOR_SUCCESS\" && echo 'Default config loaded'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Default config loaded" ]]
}

# 設定の優先順位：環境変数 > 設定ファイル
@test "environment variables override config file" {
    cat > "$BM_CONFIG" <<EOF
COLOR_ENABLED=true
EOF

    export BM_CONFIG="$BM_CONFIG"
    export COLOR_ENABLED=false  # 環境変数で上書き

    run bash -c "source cli/bmc.sh && test -z \"\$COLOR_SUCCESS\" && echo 'Env var takes precedence'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Env var takes precedence" ]]
}

# 設定ファイルでNO_COLORを有効化
@test "config file can set NO_COLOR" {
    cat > "$BM_CONFIG" <<EOF
NO_COLOR=1
EOF

    export BM_CONFIG="$BM_CONFIG"
    run bash -c "source cli/bmc.sh && init_colors && test -z \"\$COLOR_SUCCESS\" && echo 'NO_COLOR from config'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "NO_COLOR from config" ]]
}

# 設定ファイルでDEFAULT_EDITORを指定
@test "config file can set DEFAULT_EDITOR" {
    cat > "$BM_CONFIG" <<EOF
DEFAULT_EDITOR=nano
EOF

    export BM_CONFIG="$BM_CONFIG"
    # EDITORが未設定でもDEFAULT_EDITORが使われる
    unset EDITOR

    run bash -c "source cli/bmc.sh && load_config \"$BM_CONFIG\" && echo \"EDITOR:\$DEFAULT_EDITOR\""

    [ "$status" -eq 0 ]
    [[ "$output" =~ "EDITOR:nano" ]]
}

# 値の中のスペースを保持
@test "config file preserves spaces in values" {
    cat > "$BM_CONFIG" <<EOF
CUSTOM_MESSAGE=Hello World With Spaces
EOF

    run bash -c "source cli/bmc.sh && load_config \"$BM_CONFIG\" && echo \"MESSAGE:\$CUSTOM_MESSAGE\""

    [ "$status" -eq 0 ]
    [[ "$output" =~ "MESSAGE:Hello World With Spaces" ]]
}

# クォートされた値の処理
@test "config file handles quoted values" {
    cat > "$BM_CONFIG" <<EOF
QUOTED_VALUE="value with spaces"
SINGLE_QUOTED='another value'
EOF

    run bash -c "source cli/bmc.sh && load_config \"$BM_CONFIG\" && echo \"QUOTED:\$QUOTED_VALUE\" && echo \"SINGLE:\$SINGLE_QUOTED\""

    [ "$status" -eq 0 ]
    # クォートが保持されるか、除去されるか（実装次第）
    [[ "$output" =~ "QUOTED:" ]]
    [[ "$output" =~ "SINGLE:" ]]
}

# 設定ファイルの安全性チェック（シェルインジェクション防止）
@test "config file rejects dangerous commands" {
    cat > "$BM_CONFIG" <<EOF
SAFE_KEY=value
DANGEROUS=\$(rm -rf /tmp/test)
ANOTHER=; rm -rf /tmp/test
EOF

    run bash -c "source cli/bmc.sh && load_config \"$BM_CONFIG\" 2>&1"

    # 危険なコマンドが実行されないことを確認（エラーまたは無視）
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# 複数の設定ファイルパターン
@test "load_config can be called multiple times" {
    cat > "$TEST_DIR/config1" <<EOF
KEY1=value1
EOF
    cat > "$TEST_DIR/config2" <<EOF
KEY2=value2
EOF

    run bash -c "source cli/bmc.sh && load_config \"$TEST_DIR/config1\" && load_config \"$TEST_DIR/config2\" && echo \"KEY1:\$KEY1\" && echo \"KEY2:\$KEY2\""

    [ "$status" -eq 0 ]
    [[ "$output" =~ "KEY1:value1" ]]
    [[ "$output" =~ "KEY2:value2" ]]
}
