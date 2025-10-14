#!/usr/bin/env bats

# テスト前の準備
setup() {
    # テスト用の一時ディレクトリを作成
    export TEST_DIR=$(mktemp -d)
    export INSTALL_DIR="$TEST_DIR/install"
    export BIN_DIR="$INSTALL_DIR/bin"
    export HOME_BACKUP="$HOME"
    export HOME="$TEST_DIR/home"

    # テスト用のホームディレクトリを作成
    mkdir -p "$HOME"
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"

    # テスト実行前にinstall.shをPATHに追加
    export PATH="$BATS_TEST_DIRNAME/..:$PATH"
}

# テスト後のクリーンアップ
teardown() {
    # ホームディレクトリを復元
    export HOME="$HOME_BACKUP"

    # テスト用ディレクトリを削除
    [ -n "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

# インストーラーのヘルプテスト
@test "install.sh shows help when run with --help" {
    run ./install.sh --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "install.sh" ]]
}

# インストーラーの基本実行テスト
@test "install.sh creates necessary directories" {
    run ./install.sh --prefix="$INSTALL_DIR" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would create directory" ]]
}

# インストーラーのファイルコピーテスト
@test "install.sh copies bmc script to bin directory" {
    run ./install.sh --prefix="$INSTALL_DIR"
    [ "$status" -eq 0 ]
    [ -f "$BIN_DIR/bmc" ]
    [ -x "$BIN_DIR/bmc" ]
}

# エイリアス作成テスト
@test "install.sh creates bm alias when --alias-bm is specified" {
    run ./install.sh --prefix="$INSTALL_DIR" --alias-bm
    [ "$status" -eq 0 ]
    [ -f "$BIN_DIR/bm" ]
}

# XDG設定テスト
@test "install.sh configures XDG when --xdg is specified" {
    run ./install.sh --prefix="$INSTALL_DIR" --xdg
    [ "$status" -eq 0 ]
    [[ "$output" =~ "XDG" ]]
}

# シェル設定ファイル更新テスト
@test "install.sh updates shell configuration" {
    touch "$HOME/.bashrc"
    run ./install.sh --prefix="$INSTALL_DIR"
    [ "$status" -eq 0 ]

    # .bashrcにPATHとsourceが追加されているかチェック
    run grep "export PATH.*$BIN_DIR" "$HOME/.bashrc"
    [ "$status" -eq 0 ]
    run grep "source.*bmc" "$HOME/.bashrc"
    [ "$status" -eq 0 ]
}

# ドライランテスト
@test "install.sh dry-run mode does not modify files" {
    run ./install.sh --prefix="$INSTALL_DIR" --dry-run
    [ "$status" -eq 0 ]
    [ ! -f "$BIN_DIR/bmc" ]
    [[ "$output" =~ "DRY RUN" ]]
}

# 権限エラーテスト
@test "install.sh handles permission errors gracefully" {
    # 書き込み権限のないディレクトリを作成
    mkdir -p "$TEST_DIR/readonly"
    chmod 444 "$TEST_DIR/readonly"

    run ./install.sh --prefix="$TEST_DIR/readonly"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Failed" || "$output" =~ "Permission denied" || "$output" =~ "Cannot create" ]]
}

# 既存インストールのチェックテスト
@test "install.sh detects existing installation" {
    # 既存のインストールを模擬
    mkdir -p "$BIN_DIR"
    echo "#!/bin/sh" > "$BIN_DIR/bmc"
    chmod +x "$BIN_DIR/bmc"

    run ./install.sh --prefix="$INSTALL_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Existing installation" || "$output" =~ "Updating" || "$output" =~ "Installation completed" ]]
}

# アンインストールテスト
@test "install.sh supports uninstall mode" {
    # まず、インストールを実行
    ./install.sh --prefix="$INSTALL_DIR" > /dev/null 2>&1

    # アンインストールを実行
    run ./install.sh --uninstall --prefix="$INSTALL_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Uninstallation completed" || "$output" =~ "Removing" ]]

    # bmcファイルが削除されていることを確認
    [ ! -f "$BIN_DIR/bmc" ]
}