#!/bin/sh

# bookmark-cli インストーラー
# Mac/Linux対応のブックマークCLIツール

set -e

# バージョン情報
VERSION="0.1.0"
PROGRAM_NAME="bookmark-cli"

# デフォルト設定
DEFAULT_PREFIX="$HOME/.local"
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
ALIAS_TP=false
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
    --prefix=DIR            インストール先ディレクトリ (デフォルト: ~/.local)
    --bin-dir=DIR           バイナリディレクトリ (デフォルト: PREFIX/bin)
    --alias-bm              'bm' エイリアスを作成
    --alias-tp              'tp' (teleport) エイリアスを作成
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
    ./install.sh --alias-bm --alias-tp --xdg --with-mcp

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
            --alias-tp)
                ALIAS_TP=true
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

# リモートインストール用ファイルダウンロード
download_remote_files() {
    local repo_url="https://raw.githubusercontent.com/code-retriever/bookmark-cli/main"
    local temp_dir="$(mktemp -d)"

    # ログをstderrに出力（stdoutは戻り値用）
    log_info "Downloading files from GitHub..." >&2

    # cli/bmc.shをダウンロード
    if ! curl -sSL -o "$temp_dir/bmc.sh" "$repo_url/cli/bmc.sh"; then
        log_error "Failed to download bmc.sh from GitHub" >&2
        rm -rf "$temp_dir"
        exit 1
    fi

    chmod +x "$temp_dir/bmc.sh"
    echo "$temp_dir"
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
    local cleanup_temp=""

    # リモートインストールモードの検出
    if [ ! -f "$main_script" ]; then
        log_info "Local files not found. Switching to remote installation mode..."
        local temp_dir=$(download_remote_files)
        main_script="$temp_dir/bmc.sh"
        cleanup_temp="$temp_dir"
    fi

    # メインスクリプトの存在確認（再チェック）
    if [ ! -f "$main_script" ]; then
        log_error "Source file not found: $main_script"
        [ -n "$cleanup_temp" ] && rm -rf "$cleanup_temp"
        exit 1
    fi

    # メインスクリプトをコピー
    if [ "$DRY_RUN" = true ]; then
        log_info "Would copy: $main_script -> $target_bmc"
    else
        log_info "Installing: bmc -> $target_bmc"
        cp "$main_script" "$target_bmc" || {
            log_error "Failed to copy $main_script to $target_bmc"
            [ -n "$cleanup_temp" ] && rm -rf "$cleanup_temp"
            exit 1
        }
        chmod +x "$target_bmc" || {
            log_error "Failed to make $target_bmc executable"
            [ -n "$cleanup_temp" ] && rm -rf "$cleanup_temp"
            exit 1
        }
    fi

    # 一時ディレクトリのクリーンアップ
    if [ -n "$cleanup_temp" ]; then
        rm -rf "$cleanup_temp"
        log_info "Cleaned up temporary files" >&2
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

    # tpエイリアスの作成
    if [ "$ALIAS_TP" = true ]; then
        local target_tp="$BIN_DIR/tp"
        if [ "$DRY_RUN" = true ]; then
            log_info "Would create alias: tp -> $target_tp"
        else
            log_info "Creating alias: tp"
            ln -sf "$target_bmc" "$target_tp" || {
                log_error "Failed to create tp alias"
                exit 1
            }
        fi
    fi
}

# シェル設定を更新
update_shell_config() {
    local shell_configs=""
    local path_line="export PATH=\"$BIN_DIR:\$PATH\""

    # ラッパー関数定義
    local wrapper_function="# Bookmark CLI wrapper function
bmc() {
    local bmc_path=\"$BIN_DIR/bmc\"
    local result exit_code

    case \"\$1\" in
        go|g|ui|browse|fz)
            # ディレクトリ移動コマンド：出力をキャプチャ
            result=\$(\"\$bmc_path\" \"\$@\" 2>&1)
            exit_code=\$?

            if [ \$exit_code -eq 0 ] && [ -d \"\$result\" ]; then
                # 出力が有効なディレクトリなら移動
                cd \"\$result\" || return 1
                echo \"Navigated to: \$result\"
            else
                # それ以外はそのまま表示
                echo \"\$result\"
                return \$exit_code
            fi
            ;;
        *)
            # その他のコマンドは直接実行
            \"\$bmc_path\" \"\$@\"
            ;;
    esac
}"

    # tpラッパー関数定義
    local tp_wrapper_function=""
    if [ "$ALIAS_TP" = true ]; then
        tp_wrapper_function="
# Teleport (tp) wrapper function for bookmark-cli
tp() {
    local tp_path=\"$BIN_DIR/tp\"
    local result exit_code

    case \"\$1\" in
        go|g|ui|browse|fz)
            # ディレクトリ移動コマンド：出力をキャプチャ
            result=\$(\"\$tp_path\" \"\$@\" 2>&1)
            exit_code=\$?

            if [ \$exit_code -eq 0 ] && [ -d \"\$result\" ]; then
                # 出力が有効なディレクトリなら移動
                cd \"\$result\" || return 1
                echo \"Navigated to: \$result\"
            else
                # それ以外はそのまま表示
                echo \"\$result\"
                return \$exit_code
            fi
            ;;
        *)
            # その他のコマンドは直接実行
            \"\$tp_path\" \"\$@\"
            ;;
    esac
}"
    fi

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
        log_warning "  # And the bmc wrapper function"
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
        local needs_wrapper=true
        local needs_tp_wrapper=false
        local needs_xdg=false

        # 既にPATHが設定されているかチェック
        if grep -q "$BIN_DIR" "$config" 2>/dev/null; then
            log_info "PATH already configured in $config"
            needs_path=false
        fi

        # 既にbmc関数が設定されているかチェック
        if grep -q "^bmc()" "$config" 2>/dev/null || grep -q "^bmc ()" "$config" 2>/dev/null; then
            log_info "bmc wrapper function already configured in $config"
            needs_wrapper=false
        fi

        # tpラッパー関数が必要かチェック
        if [ "$ALIAS_TP" = true ]; then
            if grep -q "^tp()" "$config" 2>/dev/null || grep -q "^tp ()" "$config" 2>/dev/null; then
                log_info "tp wrapper function already configured in $config"
            else
                needs_tp_wrapper=true
            fi
        fi

        # XDG設定が必要かチェック
        if [ "$XDG_MODE" = true ]; then
            if ! grep -q "BM_FILE.*XDG_DATA_HOME" "$config" 2>/dev/null; then
                needs_xdg=true
            else
                log_info "XDG configuration already present in $config"
            fi
        fi

        if [ "$needs_path" = false ] && [ "$needs_wrapper" = false ] && [ "$needs_xdg" = false ]; then
            continue
        fi

        if [ "$DRY_RUN" = true ]; then
            [ "$needs_path" = true ] && log_info "Would add PATH to: $config"
            [ "$needs_wrapper" = true ] && log_info "Would add bmc wrapper function to: $config"
            [ "$needs_tp_wrapper" = true ] && log_info "Would add tp wrapper function to: $config"
            [ "$needs_xdg" = true ] && log_info "Would add XDG configuration to: $config"
        else
            log_info "Updating configuration in: $config"
            echo "" >> "$config"
            echo "# Added by bookmark-cli installer" >> "$config"
            [ "$needs_path" = true ] && echo "$path_line" >> "$config"
            if [ "$needs_wrapper" = true ]; then
                echo "$wrapper_function" >> "$config"
            fi
            if [ "$needs_tp_wrapper" = true ]; then
                echo "$tp_wrapper_function" >> "$config"
            fi
            if [ "$needs_xdg" = true ]; then
                echo "$xdg_lines" >> "$config"
            fi
        fi
    done
}

# 既存ブックマークを新しいXDG準拠の場所にマイグレーション
migrate_bookmarks() {
    # XDGモードが有効でない場合は何もしない
    if [ "$XDG_MODE" != true ]; then
        return
    fi

    # 既存の ~/.bm/ ディレクトリをチェック
    local old_bm_dir="$HOME/.bm"
    local old_bookmarks="$old_bm_dir/bookmarks"
    local old_history="$old_bm_dir/history"

    # 既存データがない場合は何もしない
    if [ ! -f "$old_bookmarks" ]; then
        return
    fi

    # 新しいXDG準拠のディレクトリ
    local xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
    local new_bm_dir="$xdg_data_home/bookmark-cli"
    local new_bookmarks="$new_bm_dir/bookmarks"
    local new_history="$new_bm_dir/history"

    # 既に新しい場所にデータがある場合はスキップ
    if [ -f "$new_bookmarks" ]; then
        log_info "XDG bookmarks already exist. Skipping migration."
        return
    fi

    # マイグレーション実行
    log_info "Found existing bookmarks in ~/.bm/"
    log_info "Migrating to XDG Base Directory: $new_bm_dir"

    if [ "$DRY_RUN" = true ]; then
        log_info "Would create directory: $new_bm_dir"
        log_info "Would copy: $old_bookmarks -> $new_bookmarks"
        if [ -f "$old_history" ]; then
            log_info "Would copy: $old_history -> $new_history"
        fi
    else
        # 新しいディレクトリを作成
        mkdir -p "$new_bm_dir" || {
            log_error "Failed to create directory: $new_bm_dir"
            return 1
        }

        # ブックマークをコピー
        cp "$old_bookmarks" "$new_bookmarks" || {
            log_error "Failed to copy bookmarks"
            return 1
        }
        log_success "Migrated bookmarks to $new_bookmarks"

        # 履歴をコピー（存在する場合）
        if [ -f "$old_history" ]; then
            cp "$old_history" "$new_history" || {
                log_warning "Failed to copy history"
            }
            log_success "Migrated history to $new_history"
        fi

        log_info "Migration completed. Original files in ~/.bm/ are preserved as backup."
    fi
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

    if [ "$ALIAS_TP" = true ]; then
        files_to_remove="$files_to_remove $BIN_DIR/tp"
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
    migrate_bookmarks
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