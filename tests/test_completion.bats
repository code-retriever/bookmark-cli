#!/usr/bin/env bats

setup() {
    export TEST_DIR=$(mktemp -d)
    export BM_FILE="$TEST_DIR/bookmarks"
    export BM_HISTORY="$TEST_DIR/history"

    # Create test bookmarks
    mkdir -p "$TEST_DIR/projects"
    echo "project1:$TEST_DIR/projects/proj1:Test project 1:work,dev" > "$BM_FILE"
    echo "project2:$TEST_DIR/projects/proj2:Test project 2:personal" >> "$BM_FILE"
    echo "sample-project:$TEST_DIR/projects/sample:Sample:test" >> "$BM_FILE"

    export PATH="$BATS_TEST_DIRNAME/../cli:$PATH"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "completion: bmc list outputs parseable bookmark names" {
    run bmc list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "project1" ]]
    [[ "$output" =~ "project2" ]]
    [[ "$output" =~ "sample-project" ]]
}

@test "completion: bmc list with NO_COLOR produces clean output" {
    NO_COLOR=1 run bmc list
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ $'\033' ]]
}

@test "completion: bookmark names can be extracted from list output" {
    local names=$(NO_COLOR=1 bmc list | awk 'NR > 2 && NF > 0 && $1 != "Tags:" { print $1 }')

    [ $(echo "$names" | wc -l | tr -d ' ') -eq 3 ]
    echo "$names" | grep -q "^project1$"
    echo "$names" | grep -q "^project2$"
    echo "$names" | grep -q "^sample-project$"
}

@test "completion: tags can be extracted from tags output" {
    run bmc tags
    [ "$status" -eq 0 ]
    [[ "$output" =~ "work" ]]
    [[ "$output" =~ "personal" ]]
    [[ "$output" =~ "dev" ]]
    [[ "$output" =~ "test" ]]
}

@test "completion: empty bookmark file handled gracefully" {
    > "$BM_FILE"
    run bmc list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No bookmarks found" ]]
}

@test "completion: bash completion script has valid syntax" {
    [ -f "$BATS_TEST_DIRNAME/../completions/bmc.bash" ]
    bash -n "$BATS_TEST_DIRNAME/../completions/bmc.bash"
}

@test "completion: zsh completion script exists" {
    [ -f "$BATS_TEST_DIRNAME/../completions/_bmc" ]
}

@test "completion: fish completion script exists" {
    [ -f "$BATS_TEST_DIRNAME/../completions/bmc.fish" ]
}

@test "completion: bookmark names with hyphens and underscores" {
    echo "my-project:$TEST_DIR:Test:work" >> "$BM_FILE"
    echo "my_project:$TEST_DIR:Test:work" >> "$BM_FILE"

    local names=$(NO_COLOR=1 bmc list | awk 'NR > 2 && NF > 0 && $1 != "Tags:" { print $1 }')
    echo "$names" | grep -q "my-project"
    echo "$names" | grep -q "my_project"
}

@test "completion: bmc list completes quickly with many bookmarks" {
    for i in {1..50}; do
        echo "test$i:$TEST_DIR:Test $i:test" >> "$BM_FILE"
    done

    local start=$(date +%s)
    run bmc list
    local end=$(date +%s)
    local duration=$((end - start))

    [ "$status" -eq 0 ]
    [ "$duration" -lt 2 ]
}

@test "completion: bash completion can be sourced" {
    bash -c "source $BATS_TEST_DIRNAME/../completions/bmc.bash && declare -F _bmc_completions"
}

@test "completion: bash helper functions work" {
    bash -c "
        source $BATS_TEST_DIRNAME/../completions/bmc.bash
        export BM_FILE='$BM_FILE'
        export PATH='$BATS_TEST_DIRNAME/../cli:\$PATH'
        bookmarks=\$(_bmc_get_bookmarks)
        echo \"\$bookmarks\" | grep -q 'project1'
    "
}
