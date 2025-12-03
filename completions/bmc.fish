# Fish completion for bmc (bookmark-cli)

function __fish_bmc_needs_command
    set -l cmd (commandline -opc)
    test (count $cmd) -eq 1
end

function __fish_bmc_using_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -gt 1
        test $argv[1] = $cmd[2]
    else
        return 1
    end
end

function __fish_bmc_bookmarks
    command -v bmc >/dev/null 2>&1 || return 1

    NO_COLOR=1 bmc list 2>/dev/null | \
        awk 'NR > 2 && NF > 0 && $1 != "Tags:" { print $1 }'
end

function __fish_bmc_tags
    command -v bmc >/dev/null 2>&1 || return 1

    NO_COLOR=1 bmc tags 2>/dev/null | \
        awk 'NF > 0 && $1 != "All" && $1 != "No" { print $1 }'
end

# Subcommands
complete -c bmc -f -n __fish_bmc_needs_command -a add -d 'Add a bookmark'
complete -c bmc -f -n __fish_bmc_needs_command -a a -d 'Alias for add'
complete -c bmc -f -n __fish_bmc_needs_command -a go -d 'Navigate to bookmark'
complete -c bmc -f -n __fish_bmc_needs_command -a g -d 'Alias for go'
complete -c bmc -f -n __fish_bmc_needs_command -a list -d 'List bookmarks'
complete -c bmc -f -n __fish_bmc_needs_command -a ls -d 'Alias for list'
complete -c bmc -f -n __fish_bmc_needs_command -a tags -d 'Show all tags'
complete -c bmc -f -n __fish_bmc_needs_command -a ui -d 'Interactive UI'
complete -c bmc -f -n __fish_bmc_needs_command -a browse -d 'Alias for ui'
complete -c bmc -f -n __fish_bmc_needs_command -a fz -d 'Alias for ui'
complete -c bmc -f -n __fish_bmc_needs_command -a remove -d 'Remove bookmark'
complete -c bmc -f -n __fish_bmc_needs_command -a rm -d 'Alias for remove'
complete -c bmc -f -n __fish_bmc_needs_command -a del -d 'Alias for remove'
complete -c bmc -f -n __fish_bmc_needs_command -a rename -d 'Rename bookmark'
complete -c bmc -f -n __fish_bmc_needs_command -a mv -d 'Alias for rename'
complete -c bmc -f -n __fish_bmc_needs_command -a export -d 'Export bookmarks'
complete -c bmc -f -n __fish_bmc_needs_command -a exp -d 'Alias for export'
complete -c bmc -f -n __fish_bmc_needs_command -a import -d 'Import bookmarks'
complete -c bmc -f -n __fish_bmc_needs_command -a imp -d 'Alias for import'
complete -c bmc -f -n __fish_bmc_needs_command -a edit -d 'Edit bookmark file'
complete -c bmc -f -n __fish_bmc_needs_command -a e -d 'Alias for edit'
complete -c bmc -f -n __fish_bmc_needs_command -a validate -d 'Validate bookmarks'
complete -c bmc -f -n __fish_bmc_needs_command -a check -d 'Alias for validate'
complete -c bmc -f -n __fish_bmc_needs_command -a clean -d 'Remove invalid bookmarks'
complete -c bmc -f -n __fish_bmc_needs_command -a doctor -d 'Health diagnostic'
complete -c bmc -f -n __fish_bmc_needs_command -a recent -d 'Recent bookmarks'
complete -c bmc -f -n __fish_bmc_needs_command -a r -d 'Alias for recent'
complete -c bmc -f -n __fish_bmc_needs_command -a frequent -d 'Frequent bookmarks'
complete -c bmc -f -n __fish_bmc_needs_command -a stats -d 'Usage statistics'
complete -c bmc -f -n __fish_bmc_needs_command -a help -d 'Show help'
complete -c bmc -f -n __fish_bmc_needs_command -a h -d 'Alias for help'

# Bookmark name completion
complete -c bmc -f -n '__fish_bmc_using_command go' -a '(__fish_bmc_bookmarks)'
complete -c bmc -f -n '__fish_bmc_using_command g' -a '(__fish_bmc_bookmarks)'
complete -c bmc -f -n '__fish_bmc_using_command remove' -a '(__fish_bmc_bookmarks)'
complete -c bmc -f -n '__fish_bmc_using_command rm' -a '(__fish_bmc_bookmarks)'
complete -c bmc -f -n '__fish_bmc_using_command del' -a '(__fish_bmc_bookmarks)'
complete -c bmc -f -n '__fish_bmc_using_command rename' -a '(__fish_bmc_bookmarks)'
complete -c bmc -f -n '__fish_bmc_using_command mv' -a '(__fish_bmc_bookmarks)'

# Options for add command
complete -c bmc -f -n '__fish_bmc_using_command add' -s d -l description -d 'Bookmark description'
complete -c bmc -f -n '__fish_bmc_using_command add' -s t -l tags -d 'Tags (comma-separated)'
complete -c bmc -f -n '__fish_bmc_using_command a' -s d -l description -d 'Bookmark description'
complete -c bmc -f -n '__fish_bmc_using_command a' -s t -l tags -d 'Tags (comma-separated)'

# Options for list command
complete -c bmc -f -n '__fish_bmc_using_command list' -l tag -d 'Filter by tag' -a '(__fish_bmc_tags)'
complete -c bmc -f -n '__fish_bmc_using_command ls' -l tag -d 'Filter by tag' -a '(__fish_bmc_tags)'

# Options for clean command
complete -c bmc -f -n '__fish_bmc_using_command clean' -l dry-run -d 'Preview without removing'

# Alias support
complete -c bm -w bmc
