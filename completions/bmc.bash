#!/bin/bash
# Bash completion for bmc (bookmark-cli)

_bmc_completions() {
    local cur prev words cword
    _init_completion || return

    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # All commands (primary + aliases)
    local commands="add a go g list ls tags ui browse fz remove rm del rename mv export exp import imp edit e validate check clean doctor recent r frequent stats help h"

    # First argument: complete commands
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    # Get primary command
    local cmd="${COMP_WORDS[1]}"

    # Normalize aliases
    case "$cmd" in
        a) cmd="add" ;;
        g) cmd="go" ;;
        ls) cmd="list" ;;
        browse|fz) cmd="ui" ;;
        rm|del) cmd="remove" ;;
        mv) cmd="rename" ;;
        exp) cmd="export" ;;
        imp) cmd="import" ;;
        e) cmd="edit" ;;
        check) cmd="validate" ;;
        r) cmd="recent" ;;
        h) cmd="help" ;;
    esac

    # Command-specific completion
    case "$cmd" in
        go|remove)
            local bookmarks=$(_bmc_get_bookmarks)
            COMPREPLY=( $(compgen -W "$bookmarks" -- "$cur") )
            ;;
        rename)
            if [ $COMP_CWORD -eq 2 ]; then
                local bookmarks=$(_bmc_get_bookmarks)
                COMPREPLY=( $(compgen -W "$bookmarks" -- "$cur") )
            fi
            ;;
        add)
            case "$prev" in
                -d|--description|-t|--tags)
                    COMPREPLY=()
                    ;;
                *)
                    COMPREPLY=( $(compgen -d -- "$cur") )
                    ;;
            esac
            ;;
        list)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "--tag" -- "$cur") )
            elif [[ "$prev" == "--tag" ]]; then
                local tags=$(_bmc_get_tags)
                COMPREPLY=( $(compgen -W "$tags" -- "$cur") )
            fi
            ;;
        clean)
            [[ "$cur" == -* ]] && COMPREPLY=( $(compgen -W "--dry-run" -- "$cur") )
            ;;
        import|export)
            COMPREPLY=( $(compgen -f -- "$cur") )
            ;;
    esac

    return 0
}

# Get bookmark names
_bmc_get_bookmarks() {
    local bmc_cmd="bmc"

    command -v "$bmc_cmd" >/dev/null 2>&1 || return 1

    NO_COLOR=1 "$bmc_cmd" list 2>/dev/null | \
        awk 'NR > 2 && NF > 0 && $1 != "Tags:" { print $1 }' || true
}

# Get tags
_bmc_get_tags() {
    local bmc_cmd="bmc"

    command -v "$bmc_cmd" >/dev/null 2>&1 || return 1

    NO_COLOR=1 "$bmc_cmd" tags 2>/dev/null | \
        awk 'NF > 0 && $1 != "All" && $1 != "No" { print $1 }' || true
}

complete -F _bmc_completions bmc
command -v bm >/dev/null 2>&1 && complete -F _bmc_completions bm
