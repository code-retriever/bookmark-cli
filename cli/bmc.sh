#!/bin/bash

# bookmark-cli メインスクリプト
# Mac/Linux ターミナルでディレクトリをブックマークするツール

set -e

# バージョン情報
VERSION="0.1.0"

# デフォルト設定
DEFAULT_BM_DIR="$HOME/.bm"
DEFAULT_BM_FILE="$DEFAULT_BM_DIR/bookmarks"
DEFAULT_BM_HISTORY="$DEFAULT_BM_DIR/history"

# 環境変数による設定のオーバーライド
BM_FILE="${BM_FILE:-$DEFAULT_BM_FILE}"
BM_HISTORY="${BM_HISTORY:-$DEFAULT_BM_HISTORY}"

# XDG Base Directory 対応
if [ -n "$XDG_DATA_HOME" ] && [ -z "$BM_FILE_SET" ]; then
    BM_FILE="$XDG_DATA_HOME/bookmark-cli/bookmarks"
    BM_HISTORY="$XDG_DATA_HOME/bookmark-cli/history"
fi

# ========================================
# Phase 2-1: カラー出力機能
# ========================================

# カラーコード初期化
init_colors() {
    # NO_COLOR環境変数またはCOLOR_ENABLED=falseでカラー無効化
    if [ -n "$NO_COLOR" ] || [ "$COLOR_ENABLED" = "false" ]; then
        COLOR_SUCCESS=""
        COLOR_ERROR=""
        COLOR_INFO=""
        COLOR_WARNING=""
        COLOR_RESET=""
        return
    fi

    # tputが利用可能かつターミナルが対話的な場合
    if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
        COLOR_SUCCESS="$(tput setaf 2 2>/dev/null || echo '')"   # 緑
        COLOR_ERROR="$(tput setaf 1 2>/dev/null || echo '')"     # 赤
        COLOR_INFO="$(tput setaf 4 2>/dev/null || echo '')"      # 青
        COLOR_WARNING="$(tput setaf 3 2>/dev/null || echo '')"   # 黄
        COLOR_RESET="$(tput sgr0 2>/dev/null || echo '')"
    else
        # フォールバック: 直接エスケープシーケンス（ターミナルが対話的な場合のみ）
        if [ -t 1 ]; then
            COLOR_SUCCESS="\033[0;32m"
            COLOR_ERROR="\033[0;31m"
            COLOR_INFO="\033[0;34m"
            COLOR_WARNING="\033[0;33m"
            COLOR_RESET="\033[0m"
        else
            # パイプ経由の場合はカラーなし
            COLOR_SUCCESS=""
            COLOR_ERROR=""
            COLOR_INFO=""
            COLOR_WARNING=""
            COLOR_RESET=""
        fi
    fi
}

# アイコン定義
ICON_SUCCESS="✓"
ICON_ERROR="✗"
ICON_INFO="ℹ"
ICON_WARNING="⚠"
ICON_BOOKMARK="📌"
ICON_FOLDER="📁"
ICON_TAG="🏷️ "
ICON_STATS="📊"
ICON_RECENT="🕐"

# 成功メッセージ出力
print_success() {
    echo -e "${COLOR_SUCCESS}${ICON_SUCCESS}${COLOR_RESET} $*"
}

# エラーメッセージ出力（stderr）
print_error() {
    echo -e "${COLOR_ERROR}${ICON_ERROR}${COLOR_RESET} $*" >&2
}

# 情報メッセージ出力
print_info() {
    echo -e "${COLOR_INFO}${ICON_INFO}${COLOR_RESET} $*"
}

# 警告メッセージ出力
print_warning() {
    echo -e "${COLOR_WARNING}${ICON_WARNING}${COLOR_RESET} $*"
}

# カラー初期化を実行
init_colors

# ========================================
# End of Phase 2-1
# ========================================

# ========================================
# Phase 2-2: 設定ファイル対応
# ========================================

# 設定ファイルを読み込む
load_config() {
    local config_file="$1"

    # ファイルが存在しない場合は静かに無視
    [ -f "$config_file" ] || return 0

    # KEY=VALUE形式で読み込み
    while IFS= read -r line || [ -n "$line" ]; do
        # コメント行と空行をスキップ
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue

        # KEY=VALUE形式のチェック
        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # クォートを除去
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"

            # 安全に変数を設定（exportして環境変数として利用可能に）
            export "$key=$value"
        fi
    done < "$config_file"
}

# 設定ファイルのパスを決定
get_config_path() {
    # 優先順位：BM_CONFIG > XDG_CONFIG_HOME > ~/.config
    if [ -n "$BM_CONFIG" ]; then
        echo "$BM_CONFIG"
    elif [ -n "$XDG_CONFIG_HOME" ]; then
        echo "$XDG_CONFIG_HOME/bookmark-cli/config"
    else
        echo "$HOME/.config/bookmark-cli/config"
    fi
}

# 設定ファイルを自動ロード
CONFIG_FILE=$(get_config_path)
load_config "$CONFIG_FILE"

# カラー初期化を設定ファイル読み込み後に再実行
init_colors

# ========================================
# End of Phase 2-2
# ========================================

# ブックマークファイルのディレクトリを作成
ensure_bookmark_dir() {
    bookmark_dir=$(dirname "$BM_FILE")
    if [ ! -d "$bookmark_dir" ]; then
        mkdir -p "$bookmark_dir"
    fi
}

# ヘルプメッセージを表示
show_help() {
    cat << EOF
bmc - Bookmark Manager CLI v$VERSION

Usage:
    bmc <command> [options]

Commands:
    add <name> [<path>] [-d description] [-t tags]
                            ブックマークを追加 (現在のディレクトリまたは指定パス)
    go [<name>]             ブックマークしたディレクトリへ移動 (引数なしで履歴から選択)
    list [--tag <tag>]      登録済みブックマークを一覧表示 (タグでフィルタ可能)
    tags                    登録済みタグの一覧を表示
    ui                      fzf ベースのインタラクティブ UI でブックマークをブラウズ
    remove <name>           ブックマークを削除
    rename <old> <new>      ブックマークの名前を変更
    edit                    \$EDITOR でブックマークファイルを開く
    import <file>           外部ファイルからブックマークをインポート
    export [<file>]         ブックマークを JSON/TOML 形式でエクスポート
    validate                全ブックマークの有効性を検証
    clean [--dry-run]       無効なブックマークを削除
    doctor                  ブックマークの健全性診断を表示
    recent                  最近使用したブックマークを表示
    frequent                頻繁に使用するブックマークを表示
    stats                   ブックマーク使用統計を表示
    help                    このヘルプを表示

Aliases:
    a     = add             g     = go              ls    = list
    rm    = remove          del   = remove          mv    = rename
    e     = edit            imp   = import          exp   = export
    h     = help            browse= ui              fz    = ui
    check = validate        r     = recent

Environment Variables:
    BM_FILE                 ブックマークファイルの保存先 (デフォルト: ~/.bm/bookmarks)
    EDITOR                  edit コマンドで使用するエディタ

Examples:
    bmc add project                       # 現在のディレクトリを 'project' として登録
    bmc add work ~/workspace              # 指定パスを 'work' として登録
    bmc add proj -d "My project" -t dev,work  # 説明とタグ付きで登録
    bmc go project                        # 'project' ブックマークへ移動
    bmc list                              # 登録済みブックマークを表示
    bmc list --tag work                   # 'work' タグのブックマークのみ表示
    bmc tags                              # すべてのタグを一覧表示
    bmc ui                                # fzf で選択して移動

EOF
}

# ブックマークを追加
bookmark_add() {
    local name=""
    local path=""
    local description=""
    local tags=""

    # オプション解析
    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--description)
                description="$2"
                shift 2
                ;;
            -t|--tags)
                tags="$2"
                shift 2
                ;;
            -*)
                print_error "Unknown option: $1"
                return 1
                ;;
            *)
                if [ -z "$name" ]; then
                    name="$1"
                elif [ -z "$path" ]; then
                    path="$1"
                else
                    print_error "Too many arguments"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # 引数チェック
    if [ -z "$name" ]; then
        print_error "ブックマーク名が指定されていません"
        echo "Usage: bmc add <name> [<path>] [-d description] [-t tags]" >&2
        return 1
    fi

    # パスが指定されていない場合は現在のディレクトリを使用
    if [ -z "$path" ]; then
        path="$(pwd)"
    else
        # 相対パスを絶対パスに変換
        if [ ! -d "$path" ]; then
            print_error "Directory '$path' does not exist"
            return 1
        fi
        path="$(cd "$path" && pwd)"
    fi

    ensure_bookmark_dir

    # 重複チェック
    if [ -f "$BM_FILE" ] && grep -q "^$name:" "$BM_FILE" 2>/dev/null; then
        print_error "Bookmark '$name' already exists"
        return 1
    fi

    # ブックマークを追加（新形式：name:path:description:tags）
    echo "$name:$path:$description:$tags" >> "$BM_FILE"
    print_success "Bookmark '$name' added -> $path"
    if [ -n "$description" ]; then
        echo "  Description: $description"
    fi
    if [ -n "$tags" ]; then
        echo "  Tags: $tags"
    fi
}

# ブックマーク一覧を表示
bookmark_list() {
    local filter_tag=""

    # オプション解析
    while [ $# -gt 0 ]; do
        case "$1" in
            --tag)
                filter_tag="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                return 1
                ;;
        esac
    done

    if [ ! -f "$BM_FILE" ] || [ ! -s "$BM_FILE" ]; then
        echo "No bookmarks found."
        return 0
    fi

    printf "%-20s %-30s %s\n" "NAME" "PATH" "DESCRIPTION"
    printf "%-20s %-30s %s\n" "----" "----" "-----------"

    while IFS=: read -r name path description tags _rest; do
        if [ -n "$name" ]; then
            # タグフィルタリング
            if [ -n "$filter_tag" ]; then
                # タグが指定されている場合、そのタグを含むブックマークのみ表示
                if ! echo "$tags" | grep -q "$filter_tag"; then
                    continue
                fi
            fi

            # descriptionの長さ制限（表示用）
            local display_desc="$description"
            if [ ${#display_desc} -gt 50 ]; then
                display_desc="${display_desc:0:47}..."
            fi

            printf "%-20s %-30s %s\n" "$name" "$path" "$display_desc"
            if [ -n "$tags" ]; then
                echo "  Tags: $tags"
            fi
        fi
    done < "$BM_FILE"
}

# ブックマークに移動
bookmark_go() {
    name="$1"

    # 引数なしの場合は最近の履歴から選択（fzf使用）
    if [ -z "$name" ]; then
        # fzfの存在確認
        if ! command -v fzf >/dev/null 2>&1; then
            echo "Error: ブックマーク名が指定されていません" >&2
            echo "Usage: bmc go <name>" >&2
            echo "Hint: Install fzf to select from recent history" >&2
            return 1
        fi

        # 履歴ファイルの確認
        if [ ! -f "$BM_HISTORY" ] || [ ! -s "$BM_HISTORY" ]; then
            echo "Error: No history found. Please specify a bookmark name." >&2
            echo "Usage: bmc go <name>" >&2
            return 1
        fi

        # 履歴から重複を除いて最近の10件を抽出
        local temp_file=$(mktemp)
        tac "$BM_HISTORY" 2>/dev/null | cut -d: -f2 | awk '!seen[$0]++' | head -10 > "$temp_file"

        # fzfで選択
        name=$(cat "$temp_file" | fzf \
            --height=50% \
            --layout=reverse \
            --border \
            --prompt="Select recent bookmark: " \
            --header="Recent bookmarks" \
        ) || {
            rm -f "$temp_file"
            echo "No selection made."
            return 0
        }

        rm -f "$temp_file"

        if [ -z "$name" ]; then
            echo "No selection made."
            return 0
        fi
    fi

    if [ ! -f "$BM_FILE" ]; then
        echo "Error: Bookmark '$name' not found" >&2
        return 1
    fi

    # ブックマークを検索（新形式: name:path:description:tags）
    path=$(grep "^$name:" "$BM_FILE" | cut -d: -f2)

    if [ -z "$path" ]; then
        echo "Error: Bookmark '$name' not found" >&2
        return 1
    fi

    if [ ! -d "$path" ]; then
        echo "Error: Directory '$path' no longer exists" >&2
        return 1
    fi

    # 履歴に記録
    record_history "$name"

    # シェル関数として読み込まれている場合は実際にディレクトリを変更
    # スクリプトとして実行された場合は移動用のコマンドを出力
    if [ -n "${BASH_SOURCE-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ]; then
        # Bash環境でsourceされた場合
        cd "$path" || return 1
        echo "Navigated to: $path"
    elif [ -n "${ZSH_VERSION-}" ] && [ "${(%):-%x}" != "${0}" ]; then
        # Zsh環境でsourceされた場合
        cd "$path" || return 1
        echo "Navigated to: $path"
    else
        # スクリプトとして実行された場合 - パスを出力（テスト用）
        echo "$path"
    fi
}

# ブックマークを削除
bookmark_remove() {
    name="$1"

    if [ -z "$name" ]; then
        echo "Error: ブックマーク名が指定されていません" >&2
        echo "Usage: bmc remove <name>" >&2
        return 1
    fi

    if [ ! -f "$BM_FILE" ]; then
        echo "Error: Bookmark '$name' not found" >&2
        return 1
    fi

    # ブックマークが存在するかチェック
    if ! grep -q "^$name:" "$BM_FILE" 2>/dev/null; then
        echo "Error: Bookmark '$name' not found" >&2
        return 1
    fi

    # 一時ファイルを作成してブックマークを削除
    temp_file=$(mktemp)
    grep -v "^$name:" "$BM_FILE" > "$temp_file" || true
    mv "$temp_file" "$BM_FILE"

    print_success "Bookmark '$name' removed"
}

# ファイル編集
bookmark_edit() {
    editor="${EDITOR:-vi}"
    ensure_bookmark_dir

    if [ ! -f "$BM_FILE" ]; then
        touch "$BM_FILE"
    fi

    "$editor" "$BM_FILE"
}

# ブックマークの名前を変更
bookmark_rename() {
    old_name="$1"
    new_name="$2"

    # 引数チェック
    if [ -z "$old_name" ] || [ -z "$new_name" ]; then
        echo "Error: 古い名前と新しい名前の両方を指定してください" >&2
        echo "Usage: bmc rename <old_name> <new_name>" >&2
        return 1
    fi

    if [ ! -f "$BM_FILE" ]; then
        echo "Error: Bookmark '$old_name' not found" >&2
        return 1
    fi

    # 古い名前が存在するかチェック
    if ! grep -q "^$old_name:" "$BM_FILE" 2>/dev/null; then
        echo "Error: Bookmark '$old_name' not found" >&2
        return 1
    fi

    # 新しい名前が既に存在するかチェック
    if grep -q "^$new_name:" "$BM_FILE" 2>/dev/null; then
        echo "Error: Bookmark '$new_name' already exists" >&2
        return 1
    fi

    # パスとメタデータを取得（新形式: name:path:description:tags）
    local line_content=$(grep "^$old_name:" "$BM_FILE")
    local path=$(echo "$line_content" | cut -d: -f2)
    local description=$(echo "$line_content" | cut -d: -f3)
    local tags=$(echo "$line_content" | cut -d: -f4)

    # 一時ファイルを作成して名前を変更（メタデータを保持）
    temp_file=$(mktemp)
    grep -v "^$old_name:" "$BM_FILE" > "$temp_file" || true
    echo "$new_name:$path:$description:$tags" >> "$temp_file"
    mv "$temp_file" "$BM_FILE"

    print_success "Bookmark '$old_name' renamed to '$new_name'"
}

# ブックマークをエクスポート
bookmark_export() {
    output_file="$1"

    # ブックマークファイルの存在確認
    if [ ! -f "$BM_FILE" ] || [ ! -s "$BM_FILE" ]; then
        if [ -n "$output_file" ]; then
            echo "[]" > "$output_file"
            echo "No bookmarks to export. Created empty file: $output_file"
        else
            echo "[]"
        fi
        return 0
    fi

    # JSON形式でエクスポート（メタデータ対応）
    local json_output='{"bookmarks":['
    local first=true

    while IFS=: read -r name path description tags _rest; do
        if [ -n "$name" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                json_output="$json_output,"
            fi
            # JSONエスケープ（簡易版）
            escaped_name=$(echo "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')
            escaped_path=$(echo "$path" | sed 's/\\/\\\\/g; s/"/\\"/g')
            escaped_description=$(echo "$description" | sed 's/\\/\\\\/g; s/"/\\"/g')

            # タグを配列形式に変換
            local tags_json="[]"
            if [ -n "$tags" ]; then
                tags_json="["
                local tag_first=true
                local IFS_OLD="$IFS"
                IFS=','
                for tag in $tags; do
                    if [ "$tag_first" = true ]; then
                        tag_first=false
                    else
                        tags_json="$tags_json, "
                    fi
                    escaped_tag=$(echo "$tag" | sed 's/\\/\\\\/g; s/"/\\"/g')
                    tags_json="$tags_json\"$escaped_tag\""
                done
                IFS="$IFS_OLD"
                tags_json="$tags_json]"
            fi

            json_output="$json_output
    {
      \"name\": \"$escaped_name\",
      \"path\": \"$escaped_path\",
      \"description\": \"$escaped_description\",
      \"tags\": $tags_json
    }"
        fi
    done < "$BM_FILE"

    json_output="$json_output
  ]
}"

    if [ -n "$output_file" ]; then
        echo "$json_output" > "$output_file"
        print_success "Exported $(grep -c ":" "$BM_FILE") bookmarks to: $output_file"
    else
        echo "$json_output"
    fi
}

# ブックマークをインポート
bookmark_import() {
    import_file="$1"

    # 引数チェック
    if [ -z "$import_file" ]; then
        echo "Error: インポートファイルを指定してください" >&2
        echo "Usage: bmc import <file>" >&2
        return 1
    fi

    # ファイルの存在確認
    if [ ! -f "$import_file" ]; then
        echo "Error: File '$import_file' does not exist" >&2
        return 1
    fi

    ensure_bookmark_dir

    # ファイル形式を判定（JSON or 単純な name:path 形式）
    if grep -q "^\[" "$import_file" 2>/dev/null || grep -q "^{" "$import_file" 2>/dev/null; then
        # JSON形式のインポート
        import_json_file "$import_file"
    else
        # 単純な name:path 形式のインポート
        import_simple_file "$import_file"
    fi
}

# JSON形式のファイルをインポート
import_json_file() {
    local file="$1"
    local imported_count=0
    local skipped_count=0

    # jqが利用可能な場合
    if command -v jq >/dev/null 2>&1; then
        # jqを使ってJSONを解析（一時ファイルを使用）
        local temp_json_file=$(mktemp)
        # 新形式と旧形式の両方に対応
        if jq -e '.bookmarks' "$file" >/dev/null 2>&1; then
            # 新形式: {"bookmarks": [...]}
            jq -c '.bookmarks[]' "$file" 2>/dev/null > "$temp_json_file" || {
                rm -f "$temp_json_file"
                echo "Error: Invalid JSON format" >&2
                return 1
            }
        else
            # 旧形式: [...]
            jq -c '.[]' "$file" 2>/dev/null > "$temp_json_file" || {
                rm -f "$temp_json_file"
                echo "Error: Invalid JSON format" >&2
                return 1
            }
        fi

        while IFS= read -r line; do
            if [ -n "$line" ]; then
                name=$(echo "$line" | jq -r '.name')
                path=$(echo "$line" | jq -r '.path')
                description=$(echo "$line" | jq -r '.description // ""')
                tags_array=$(echo "$line" | jq -r '.tags // [] | join(",")')

                if [ "$name" != "null" ] && [ "$path" != "null" ]; then
                    if import_bookmark "$name" "$path" "$description" "$tags_array"; then
                        imported_count=$((imported_count + 1))
                    else
                        skipped_count=$((skipped_count + 1))
                    fi
                fi
            fi
        done < "$temp_json_file"

        rm -f "$temp_json_file"
    else
        # jqが利用できない場合の簡易JSON解析（メタデータ対応）
        local in_array=false
        local name="" path="" description="" tags=""
        while IFS= read -r line; do
            line=$(echo "$line" | sed 's/^[ \t]*//') # 先頭の空白を削除

            case "$line" in
                "["*|"\"bookmarks\":"*"["*)
                    in_array=true
                    ;;
                "]"*)
                    # 最後のエントリを処理
                    if [ -n "$name" ] && [ -n "$path" ]; then
                        if import_bookmark "$name" "$path" "$description" "$tags"; then
                            imported_count=$((imported_count + 1))
                        else
                            skipped_count=$((skipped_count + 1))
                        fi
                        name="" path="" description="" tags=""
                    fi
                    in_array=false
                    ;;
                "\"name\":"*)
                    if [ "$in_array" = true ]; then
                        name=$(echo "$line" | sed 's/.*"name":[ \t]*"\([^"]*\)".*/\1/')
                    fi
                    ;;
                "\"path\":"*)
                    if [ "$in_array" = true ]; then
                        path=$(echo "$line" | sed 's/.*"path":[ \t]*"\([^"]*\)".*/\1/')
                    fi
                    ;;
                "\"description\":"*)
                    if [ "$in_array" = true ]; then
                        description=$(echo "$line" | sed 's/.*"description":[ \t]*"\([^"]*\)".*/\1/')
                    fi
                    ;;
                "\"tags\":"*)
                    if [ "$in_array" = true ]; then
                        # タグ配列を抽出してカンマ区切りに変換（簡易版）
                        tags=$(echo "$line" | sed 's/.*"tags":[ \t]*\[\(.*\)\].*/\1/' | sed 's/"//g' | sed 's/ //g')
                    fi
                    ;;
                "}"*)
                    # オブジェクトの終わりで処理
                    if [ -n "$name" ] && [ -n "$path" ]; then
                        if import_bookmark "$name" "$path" "$description" "$tags"; then
                            imported_count=$((imported_count + 1))
                        else
                            skipped_count=$((skipped_count + 1))
                        fi
                        name="" path="" description="" tags=""
                    fi
                    ;;
            esac
        done < "$file"
    fi

    if [ $imported_count -eq 0 ] && [ $skipped_count -eq 0 ]; then
        print_error "Invalid JSON format or no valid bookmarks found"
        return 1
    fi

    print_success "Imported $imported_count bookmarks"
    if [ $skipped_count -gt 0 ]; then
        print_info "Skipped $skipped_count duplicates"
    fi
}

# 単純な形式のファイルをインポート（新旧形式両対応）
import_simple_file() {
    local file="$1"
    local imported_count=0
    local skipped_count=0

    while IFS=: read -r name path description tags _rest; do
        if [ -n "$name" ] && [ -n "$path" ]; then
            # 新形式（4フィールド）と旧形式（2フィールド）の両方に対応
            if import_bookmark "$name" "$path" "$description" "$tags"; then
                imported_count=$((imported_count + 1))
            else
                skipped_count=$((skipped_count + 1))
            fi
        fi
    done < "$file"

    # エラーチェック：何もインポートできなかった場合
    if [ $imported_count -eq 0 ] && [ $skipped_count -eq 0 ]; then
        print_error "No valid bookmarks found in file"
        return 1
    fi

    print_success "Imported $imported_count bookmarks"
    if [ $skipped_count -gt 0 ]; then
        print_info "Skipped $skipped_count duplicates"
    fi
}

# 単一のブックマークをインポート（重複チェック付き、メタデータ対応）
import_bookmark() {
    local name="$1"
    local path="$2"
    local description="${3:-}"
    local tags="${4:-}"

    # 重複チェック
    if [ -f "$BM_FILE" ] && grep -q "^$name:" "$BM_FILE" 2>/dev/null; then
        return 1  # 重複（失敗）
    fi

    # ブックマークを追加（新形式：name:path:description:tags）
    echo "$name:$path:$description:$tags" >> "$BM_FILE"
    return 0  # 成功
}

# ブックマークを検証
bookmark_validate() {
    if [ ! -f "$BM_FILE" ] || [ ! -s "$BM_FILE" ]; then
        echo "No bookmarks found."
        return 0
    fi

    local total_count=0
    local valid_count=0
    local invalid_count=0
    local invalid_list=""

    while IFS=: read -r name path description tags _rest; do
        if [ -n "$name" ]; then
            total_count=$((total_count + 1))
            if [ -d "$path" ]; then
                valid_count=$((valid_count + 1))
            else
                invalid_count=$((invalid_count + 1))
                invalid_list="$invalid_list$name -> $path\n"
            fi
        fi
    done < "$BM_FILE"

    if [ $invalid_count -eq 0 ]; then
        echo "✓ All bookmarks are valid ($valid_count/$total_count)"
        return 0
    else
        echo "✗ Found $invalid_count invalid bookmark(s) out of $total_count:"
        echo ""
        printf "$invalid_list"
        return 1
    fi
}

# 無効なブックマークを削除
bookmark_clean() {
    local dry_run=false

    # オプション解析
    if [ "$1" = "--dry-run" ]; then
        dry_run=true
    fi

    if [ ! -f "$BM_FILE" ] || [ ! -s "$BM_FILE" ]; then
        echo "No bookmarks to clean."
        return 0
    fi

    local removed_count=0
    local temp_file=$(mktemp)

    while IFS=: read -r name path description tags _rest; do
        if [ -n "$name" ]; then
            if [ -d "$path" ]; then
                # 有効なブックマークは保持（メタデータも保持）
                echo "$name:$path:$description:$tags" >> "$temp_file"
            else
                # 無効なブックマーク
                removed_count=$((removed_count + 1))
                if [ "$dry_run" = true ]; then
                    echo "Would remove: $name -> $path"
                else
                    echo "Removed: $name -> $path"
                fi
            fi
        fi
    done < "$BM_FILE"

    if [ $removed_count -eq 0 ]; then
        rm -f "$temp_file"
        echo "No invalid bookmarks found. All bookmarks are valid."
        return 0
    fi

    if [ "$dry_run" = true ]; then
        rm -f "$temp_file"
        echo ""
        print_info "Dry run completed. $removed_count bookmark(s) would be removed."
    else
        mv "$temp_file" "$BM_FILE"
        echo ""
        print_success "Cleaned $removed_count invalid bookmark(s)."
    fi

    return 0
}

# ブックマークの診断情報を表示
bookmark_doctor() {
    echo "=== Bookmark Health Diagnostic ==="
    echo ""

    if [ ! -f "$BM_FILE" ] || [ ! -s "$BM_FILE" ]; then
        echo "Status: No bookmarks file found"
        echo "Recommendation: Add some bookmarks with 'bmc add'"
        return 0
    fi

    local total_count=0
    local valid_count=0
    local invalid_count=0
    local invalid_details=""

    while IFS=: read -r name path description tags _rest; do
        if [ -n "$name" ]; then
            total_count=$((total_count + 1))
            if [ -d "$path" ]; then
                valid_count=$((valid_count + 1))
            else
                invalid_count=$((invalid_count + 1))
                invalid_details="$invalid_details  • $name\n    Path: $path\n    Issue: Directory not found\n\n"
            fi
        fi
    done < "$BM_FILE"

    # 統計情報
    echo "Statistics:"
    echo "  Total bookmarks: $total_count"
    echo "  Valid: $valid_count"
    echo "  Invalid: $invalid_count"
    echo ""

    if [ $invalid_count -eq 0 ]; then
        echo "Health Status: ✓ Healthy"
        echo "All bookmarks are valid and accessible."
    else
        echo "Health Status: ✗ Issues found"
        echo ""
        echo "Invalid Bookmarks:"
        printf "$invalid_details"
        echo "Recommendations:"
        echo "  1. Run 'bmc clean' to remove invalid bookmarks"
        echo "  2. Or manually fix the paths with 'bmc edit'"
    fi

    return 0
}

# 履歴にブックマーク使用を記録
record_history() {
    local name="$1"
    ensure_bookmark_dir

    # タイムスタンプ:ブックマーク名の形式で追加
    echo "$(date +%s):$name" >> "$BM_HISTORY"
}

# 最近使用したブックマークを表示
bookmark_recent() {
    if [ ! -f "$BM_HISTORY" ] || [ ! -s "$BM_HISTORY" ]; then
        echo "No history found."
        return 0
    fi

    echo "Recent bookmarks (last 10):"
    echo ""
    printf "%-20s %s\n" "NAME" "LAST USED"
    printf "%-20s %s\n" "----" "---------"

    # 履歴を逆順（最新が上）で表示、重複を除去して最新のみ表示
    local seen_names=""
    local count=0

    # ファイルを逆順で読む
    tac "$BM_HISTORY" 2>/dev/null | while IFS=: read -r timestamp name; do
        # 既に表示した名前はスキップ
        if [ $count -ge 10 ]; then
            break
        fi

        # 名前の重複チェック
        if ! echo "$seen_names" | grep -q "^$name\$"; then
            seen_names="$seen_names
$name"
            # タイムスタンプを人間が読める形式に変換
            time_str=$(date -r "$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || date -d "@$timestamp" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "Unknown")
            printf "%-20s %s\n" "$name" "$time_str"
            count=$((count + 1))
        fi
    done
}

# 頻繁に使用するブックマークを表示
bookmark_frequent() {
    if [ ! -f "$BM_HISTORY" ] || [ ! -s "$BM_HISTORY" ]; then
        echo "No history found."
        return 0
    fi

    echo "Frequently used bookmarks:"
    echo ""
    printf "%-20s %s\n" "NAME" "COUNT"
    printf "%-20s %s\n" "----" "-----"

    # 各ブックマークの使用回数をカウントしてソート
    cut -d: -f2 "$BM_HISTORY" | sort | uniq -c | sort -rn | head -10 | while read -r count name; do
        printf "%-20s %d\n" "$name" "$count"
    done
}

# ブックマーク使用統計を表示
bookmark_stats() {
    if [ ! -f "$BM_HISTORY" ] || [ ! -s "$BM_HISTORY" ]; then
        echo "No history found."
        return 0
    fi

    local total_uses=$(wc -l < "$BM_HISTORY" | tr -d ' ')
    local unique_bookmarks=$(cut -d: -f2 "$BM_HISTORY" | sort -u | wc -l | tr -d ' ')
    local most_used=$(cut -d: -f2 "$BM_HISTORY" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    local most_used_count=$(cut -d: -f2 "$BM_HISTORY" | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')

    echo "=== Bookmark Usage Statistics ==="
    echo ""
    echo "Total accesses: $total_uses"
    echo "Unique bookmarks used: $unique_bookmarks"
    echo "Most used: $most_used ($most_used_count times)"
    echo ""
    echo "Top 5 bookmarks:"
    cut -d: -f2 "$BM_HISTORY" | sort | uniq -c | sort -rn | head -5 | while read -r count name; do
        echo "  $count × $name"
    done
}

# インタラクティブUI（fzf使用）
bookmark_ui() {
    # fzfの存在確認
    if ! command -v fzf >/dev/null 2>&1; then
        echo "Error: fzf is required for UI mode but not found" >&2
        echo "Please install fzf first:" >&2
        echo "  macOS: brew install fzf" >&2
        echo "  Ubuntu: sudo apt install fzf" >&2
        return 1
    fi

    # ブックマークファイルの存在確認
    if [ ! -f "$BM_FILE" ] || [ ! -s "$BM_FILE" ]; then
        echo "No bookmarks found. Add some bookmarks first:"
        echo "  bmc add <name> [<path>]"
        return 0
    fi

    # ブックマーク一覧を整形してfzfに渡す
    local temp_file=$(mktemp)

    # ブックマーク情報を整形（名前、パス、説明を表示）
    while IFS=: read -r name path description tags _rest; do
        if [ -n "$name" ]; then
            # 説明の長さ制限
            local short_desc="$description"
            if [ ${#short_desc} -gt 30 ]; then
                short_desc="${short_desc:0:27}..."
            fi
            printf "%-20s %-40s %s\n" "$name" "$path" "$short_desc"
        fi
    done < "$BM_FILE" > "$temp_file"

    # fzfでブックマークを選択
    local selected
    selected=$(cat "$temp_file" | fzf \
        --height=50% \
        --layout=reverse \
        --border \
        --prompt="Select bookmark: " \
        --preview-window=right:50% \
        --preview="name=\$(/usr/bin/awk '{print \$1}' <<< {}); line=\$(/usr/bin/grep \"^\$name:\" \"$BM_FILE\"); path=\$(/usr/bin/cut -d: -f2 <<< \"\$line\"); desc=\$(/usr/bin/cut -d: -f3 <<< \"\$line\"); tags=\$(/usr/bin/cut -d: -f4 <<< \"\$line\"); echo \"Name: \$name\"; echo \"Path: \$path\"; [ -n \"\$desc\" ] && echo \"Description: \$desc\"; [ -n \"\$tags\" ] && echo \"Tags: \$tags\"; echo \"\"; if [ -d \"\$path\" ]; then echo \"Status: Directory exists ✓\"; echo \"\"; /bin/ls -la \"\$path\" 2>/dev/null | /usr/bin/head -10; else echo \"Status: Directory not found ✗\"; fi" \
        --bind="ctrl-r:reload(cat $temp_file)" \
        --header="Enter: Navigate, Ctrl-C: Cancel, Ctrl-R: Refresh" \
    ) || {
        rm -f "$temp_file"
        echo "No selection made."
        return 0
    }

    rm -f "$temp_file"

    if [ -z "$selected" ]; then
        echo "No selection made."
        return 0
    fi

    # 選択されたブックマーク名を抽出
    local bookmark_name
    bookmark_name=$(echo "$selected" | awk '{print $1}')

    if [ -z "$bookmark_name" ]; then
        echo "Error: Invalid selection" >&2
        return 1
    fi

    # 選択されたブックマークに移動（bookmark_go内で履歴記録される）
    bookmark_go "$bookmark_name"
}

# すべてのタグを一覧表示
bookmark_tags() {
    if [ ! -f "$BM_FILE" ] || [ ! -s "$BM_FILE" ]; then
        echo "No bookmarks found."
        return 0
    fi

    echo "All tags:"
    echo ""

    # すべてのタグを抽出してユニーク化、ソート
    local all_tags=""
    while IFS=: read -r name path description tags _rest; do
        if [ -n "$tags" ]; then
            # タグをカンマで分割して追加
            local IFS_OLD="$IFS"
            IFS=','
            for tag in $tags; do
                all_tags="$all_tags
$tag"
            done
            IFS="$IFS_OLD"
        fi
    done < "$BM_FILE"

    # ユニーク化してソート、表示
    if [ -n "$all_tags" ]; then
        echo "$all_tags" | grep -v "^$" | sort -u | while read -r tag; do
            # 各タグを持つブックマークの数をカウント
            local count=$(grep -c ":.*:.*:.*$tag" "$BM_FILE" 2>/dev/null || echo 0)
            printf "  %-20s (%d bookmark(s))\n" "$tag" "$count"
        done
    else
        echo "  No tags found."
    fi
}

# メイン処理
main() {
    # グローバルオプション処理（--no-color）
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-color)
                export NO_COLOR=1
                init_colors  # カラーを再初期化
                shift
                ;;
            *)
                break
                ;;
        esac
    done

    case "${1:-}" in
        add|a)
            shift
            # コマンドレベルの--no-colorオプション処理
            while [ $# -gt 0 ]; do
                case "$1" in
                    --no-color)
                        export NO_COLOR=1
                        init_colors
                        shift
                        ;;
                    *)
                        break
                        ;;
                esac
            done
            bookmark_add "$@"
            ;;
        go|g)
            shift
            bookmark_go "$@"
            ;;
        list|ls)
            shift
            bookmark_list "$@"
            ;;
        tags)
            bookmark_tags
            ;;
        ui|browse|fz)
            bookmark_ui
            ;;
        remove|rm|del)
            shift
            bookmark_remove "$@"
            ;;
        rename|mv)
            shift
            bookmark_rename "$@"
            ;;
        export|exp)
            shift
            bookmark_export "$@"
            ;;
        import|imp)
            shift
            bookmark_import "$@"
            ;;
        edit|e)
            bookmark_edit
            ;;
        validate|check)
            bookmark_validate
            ;;
        clean)
            shift
            bookmark_clean "$@"
            ;;
        doctor)
            bookmark_doctor
            ;;
        recent|r)
            bookmark_recent
            ;;
        frequent)
            bookmark_frequent
            ;;
        stats)
            bookmark_stats
            ;;
        help|h|--help|-h)
            show_help
            ;;
        "")
            show_help
            ;;
        *)
            echo "Error: Unknown command '$1'" >&2
            echo "Run 'bmc help' for usage information." >&2
            return 1
            ;;
    esac
}

# スクリプトが直接実行された場合のみmain関数を呼び出す
if [ "${BASH_SOURCE-}" = "${0}" ] || [ -z "${BASH_SOURCE+x}" ]; then
    main "$@"
fi