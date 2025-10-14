#!/bin/sh

# bookmark-cli インストーラー
# Mac/Linux対応のブックマークCLIツール

set -e

# バージョン情報
VERSION="0.1.0"
PROGRAM_NAME="bookmark-cli"

# デフォルト設定
DEFAULT_PREFIX="/usr/local"
DEFAULT_BIN_DIR="$DEFAULT_PREFIX/bin"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# オプション変数
PREFIX="$DEFAULT_PREFIX"
BIN_DIR=""
DRY_RUN=false
ALIAS_BM=false
XDG_MODE=false
WITH_MCP=false
UNINSTALL=false
FORCE=false

# ログ関数
log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

# ヘルプメッセージ
show_help() {
    cat << EOF
${PROGRAM_NAME} インストーラー v${VERSION}

Usage:
    install.sh [options]

Options:
    --prefix=DIR            インストール先ディレクトリ (デフォルト: $DEFAULT_PREFIX)
    --bin-dir=DIR           バイナリディレクトリ (デフォルト: PREFIX/bin)
    --alias-bm              'bm' エイリアスを作成
    --xdg                   XDG Base Directory 設定を有効化
    --with-mcp              MCP サーバも同時にインストール
    --dry-run               実際のインストールは行わず、実行予定の操作を表示
    --uninstall             アンインストールを実行
    --force                 既存ファイルを強制上書き
    --help, -h              このヘルプを表示

Examples:
    # 標準インストール
    ./install.sh

    # カスタムディレクトリにインストール
    ./install.sh --prefix=/opt/bookmark-cli

    # フル機能でインストール
    ./install.sh --alias-bm --xdg --with-mcp

    # ドライラン
    ./install.sh --dry-run

    # アンインストール
    ./install.sh --uninstall

Environment Variables:
    PREFIX                  インストール先ディレクトリ
    BIN_DIR                 バイナリディレクトリ

EOF
}

# コマンドライン引数を解析
parse_args() {
    while [ $# -gt 0 ]; do
        case $1 in
            --prefix=*)
                PREFIX="${1#*=}"
                ;;
            --bin-dir=*)
                BIN_DIR="${1#*=}"
                ;;
            --alias-bm)
                ALIAS_BM=true
                ;;
            --xdg)
                XDG_MODE=true
                ;;
            --with-mcp)
                WITH_MCP=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --uninstall)
                UNINSTALL=true
                ;;
            --force)
                FORCE=true
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                log_error "Run 'install.sh --help' for usage information."
                exit 1
                ;;
        esac
        shift
    done

    # BIN_DIRが指定されていない場合はPREFIX/binを使用
    if [ -z "$BIN_DIR" ]; then
        BIN_DIR="$PREFIX/bin"
    fi
}

# 環境変数からオプションを読み込み
load_env_vars() {
    [ -n "$PREFIX" ] && PREFIX="$PREFIX"
    [ -n "$BIN_DIR" ] && BIN_DIR="$BIN_DIR"
}

# 依存関係チェック
check_dependencies() {
    local missing_deps=""

    # 基本コマンドをチェック
    for cmd in cp mkdir chmod grep awk; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps="$missing_deps $cmd"
        fi
    done

    # MCP有効時のNode.jsチェック
    if [ "$WITH_MCP" = true ]; then
        if ! command -v node >/dev/null 2>&1; then
            log_warning "Node.js が見つかりません。MCP機能にはNode.js v16以上が必要です。"
        fi
    fi

    if [ -n "$missing_deps" ]; then
        log_error "Missing dependencies:$missing_deps"
        exit 1
    fi
}

# ディレクトリ作成
create_directories() {
    local dirs="$BIN_DIR"

    for dir in $dirs; do
        if [ "$DRY_RUN" = true ]; then
            log_info "Would create directory: $dir"
        else
            if [ ! -d "$dir" ]; then
                log_info "Creating directory: $dir"
                mkdir -p "$dir" || {
                    log_error "Failed to create directory: $dir"
                    exit 1
                }
            fi
        fi
    done
}

# ファイルをインストール
install_files() {
    local source_dir="$(dirname "$0")"
    local main_script="$source_dir/cli/bmc.sh"
    local target_bmc="$BIN_DIR/bmc"

    # メインスクリプトの存在確認
    if [ ! -f "$main_script" ]; then
        log_error "Source file not found: $main_script"
        exit 1
    fi

    # メインスクリプトをコピー
    if [ "$DRY_RUN" = true ]; then
        log_info "Would copy: $main_script -> $target_bmc"
    else
        log_info "Installing: bmc -> $target_bmc"
        cp "$main_script" "$target_bmc" || {
            log_error "Failed to copy $main_script to $target_bmc"
            exit 1
        }
        chmod +x "$target_bmc" || {
            log_error "Failed to make $target_bmc executable"
            exit 1
        }
    fi

    # bmエイリアスの作成
    if [ "$ALIAS_BM" = true ]; then
        local target_bm="$BIN_DIR/bm"
        if [ "$DRY_RUN" = true ]; then
            log_info "Would create alias: bm -> $target_bm"
        else
            log_info "Creating alias: bm"
            ln -sf "$target_bmc" "$target_bm" || {
                log_error "Failed to create bm alias"
                exit 1
            }
        fi
    fi
}

# シェル設定を更新
update_shell_config() {
    local shell_configs=""
    local path_line="export PATH=\"$BIN_DIR:\$PATH\""
    local source_line="source \"$BIN_DIR/bmc\""

    # XDG Base Directory設定
    local xdg_lines=""
    if [ "$XDG_MODE" = true ]; then
        xdg_lines="# XDG Base Directory configuration for bookmark-cli
export XDG_DATA_HOME=\"\${XDG_DATA_HOME:-\$HOME/.local/share}\"
export BM_FILE=\"\$XDG_DATA_HOME/bookmark-cli/bookmarks\"
export BM_HISTORY=\"\$XDG_DATA_HOME/bookmark-cli/history\""
        log_info "XDG Base Directory mode enabled"
    fi

    # シェル設定ファイルを特定
    if [ -n "$HOME" ]; then
        for config in .bashrc .zshrc .profile; do
            if [ -f "$HOME/$config" ]; then
                shell_configs="$shell_configs $HOME/$config"
            fi
        done
    fi

    if [ -z "$shell_configs" ]; then
        log_warning "Shell configuration files not found. Please manually add:"
        log_warning "  export PATH=\"$BIN_DIR:\$PATH\""
        log_warning "  source \"$BIN_DIR/bmc\""
        if [ "$XDG_MODE" = true ]; then
            log_warning "  # XDG Base Directory configuration"
            log_warning "  export XDG_DATA_HOME=\"\${XDG_DATA_HOME:-\$HOME/.local/share}\""
            log_warning "  export BM_FILE=\"\$XDG_DATA_HOME/bookmark-cli/bookmarks\""
            log_warning "  export BM_HISTORY=\"\$XDG_DATA_HOME/bookmark-cli/history\""
        fi
        return
    fi

    for config in $shell_configs; do
        local needs_path=true
        local needs_source=true
        local needs_xdg=false

        # 既にPATHが設定されているかチェック
        if grep -q "$BIN_DIR" "$config" 2>/dev/null; then
            log_info "PATH already configured in $config"
            needs_path=false
        fi

        # 既にsourceが設定されているかチェック
        if grep -q "source.*bmc" "$config" 2>/dev/null; then
            log_info "Source already configured in $config"
            needs_source=false
        fi

        # XDG設定が必要かチェック
        if [ "$XDG_MODE" = true ]; then
            if ! grep -q "BM_FILE.*XDG_DATA_HOME" "$config" 2>/dev/null; then
                needs_xdg=true
            else
                log_info "XDG configuration already present in $config"
            fi
        fi

        if [ "$needs_path" = false ] && [ "$needs_source" = false ] && [ "$needs_xdg" = false ]; then
            continue
        fi

        if [ "$DRY_RUN" = true ]; then
            [ "$needs_path" = true ] && log_info "Would add PATH to: $config"
            [ "$needs_source" = true ] && log_info "Would add source to: $config"
            [ "$needs_xdg" = true ] && log_info "Would add XDG configuration to: $config"
        else
            log_info "Updating configuration in: $config"
            echo "" >> "$config"
            echo "# Added by bookmark-cli installer" >> "$config"
            [ "$needs_path" = true ] && echo "$path_line" >> "$config"
            [ "$needs_source" = true ] && echo "$source_line" >> "$config"
            if [ "$needs_xdg" = true ]; then
                echo "$xdg_lines" >> "$config"
            fi
        fi
    done
}

# MCP サーバーをインストール
install_mcp_server() {
    if [ "$WITH_MCP" != true ]; then
        return
    fi

    log_info "MCP server installation is not yet implemented"
    log_warning "Use --with-mcp when MCP feature is ready"
}

# アンインストール
uninstall() {
    log_info "Starting uninstallation..."

    local files_to_remove="$BIN_DIR/bmc"

    if [ "$ALIAS_BM" = true ]; then
        files_to_remove="$files_to_remove $BIN_DIR/bm"
    fi

    for file in $files_to_remove; do
        if [ -f "$file" ]; then
            if [ "$DRY_RUN" = true ]; then
                log_info "Would remove: $file"
            else
                log_info "Removing: $file"
                rm -f "$file"
            fi
        else
            log_warning "File not found: $file"
        fi
    done

    log_success "Uninstallation completed"
    log_info "Note: Shell configuration files were not modified. Please remove PATH entries manually if needed."
}

# メインインストール処理
main_install() {
    log_info "Starting installation of $PROGRAM_NAME v$VERSION..."

    if [ "$DRY_RUN" = true ]; then
        log_info "=== DRY RUN MODE ==="
    fi

    # 既存インストールをチェック
    if [ -f "$BIN_DIR/bmc" ] && [ "$FORCE" != true ]; then
        log_info "Existing installation found. Updating..."
    fi

    check_dependencies
    create_directories
    install_files
    update_shell_config
    install_mcp_server

    if [ "$DRY_RUN" = true ]; then
        log_info "=== DRY RUN COMPLETED ==="
    else
        log_success "Installation completed successfully!"
        log_info "Installed to: $BIN_DIR/bmc"
        log_info "Please restart your shell or run: source ~/.bashrc (or ~/.zshrc)"
        log_info "Test installation: bmc --help"
    fi
}

# メイン処理
main() {
    parse_args "$@"
    load_env_vars

    if [ "$UNINSTALL" = true ]; then
        uninstall
    else
        main_install
    fi
}

# スクリプトが直接実行された場合のみmain関数を呼び出す
if [ "${BASH_SOURCE-}" = "${0}" ] || [ -z "${BASH_SOURCE+x}" ]; then
    main "$@"
fi