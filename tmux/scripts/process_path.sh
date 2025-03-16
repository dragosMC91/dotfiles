#!/bin/bash

# this script takes a string input and extracts a filepath / url / other
# which is processed, and opened in the appropriate app.
# For example, when you cmd+click a filepath like /my/file.js:55:2
# nothing happens in a terminal like ghostty (no have support yet)
# vs using the vscode terminal emulator which opens the file at line 55, column 2
# when updating the script logic, run the unit tests to make sure nothing breaks via
# echo "run tests" | ./process_path.sh

# Debug function that only prints to console when DEBUG is set
# or shows it in the status bar when in a tmux context
debug() {
    if [ ! -z "${DEBUG}" ]; then
        echo "[DEBUG] $*" >&2
    fi
    if [ -n "$TMUX" ]; then
        tmux display-message -d 2000 "$*"
    fi
}

get_current_dir() {
    local current_dir
    # Check if running inside tmux and fetch the pane's current directory
    if [ -n "$TMUX" ]; then
        current_dir=$(tmux display-message -p -F "#{pane_current_path}")
    else
        current_dir=$(pwd)
    fi
    echo "$current_dir"
}

process_path() {
    local multiline_string="$1"
    local current_dir="$2"
    local path
    local type
    local status="File found"

    # Extract the path using grep and regular expressions
    path=$(echo "$multiline_string" | grep -oE "(file:///)?(\.{0,2}/[^[:space:]]+|/[^[:space:]]+|\w+:\/\/[^[:space:]]+)|www\.[^[:space:]]+")

    if [[ -z "$path" ]]; then
        echo "No path found"
        return
    fi

    # Handle :line:column suffix
    if [[ "$path" =~ (:[0-9]+(:[0-9]+)?) ]]; then
        suffix="${BASH_REMATCH[1]}"
        path=$(echo "$path" | sed "s/$suffix.*//")
    else
        suffix=""
    fi

    # Handle file:/// prefix paths
    if [[ "$path" =~ ^file:/// ]]; then
        path="${path#file://}"
    fi

    if [[ ! -e "$path" ]]; then
        # If path doesn't exist, check if $current_dir$path exists
        # and prepend the current directory if it exists
        if [[ -e "$current_dir$path" ]]; then
            path="$current_dir$path"
        fi
    fi

    # Handle relative paths
    if [[ "$path" =~ ^\.{1,2}\/ ]]; then
        path="$current_dir/$path"
    fi

    # Determine the type of path
    if [[ "$path" =~ ^(http|https|www) ]]; then
        type="url"
    elif [[ "$path" =~ \.(py|sh|js|ts|tsx) ]]; then
        type="code"
    else
        type="default"
    fi

    if [[ "$type" == "url" || ! -f "$path" ]]; then
        status="File not found"
    fi

    echo "$type|$path$suffix|$status"
}

# Read from stdin (pipe) and process
read -r path

if [[ "$path" == "run tests" ]]; then
    # ANSI color codes
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m'
    
    # Helper function to run test cases
    run_test() {
    local test_name="$1"
    local input="$2"
    local current_dir="$3"
    local expected="$4"
    local actual

    actual=$(process_path "$input" "$current_dir")

    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}PASS:${NC} $test_name"
    else
        echo -e "${RED}FAIL:${NC} $test_name"
        echo "  Input: $input"
        echo "  Current Dir: $current_dir"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
    fi
    }
    # Create a dummy file for testing
    mkdir -p /tmp/some/path/touch && touch /tmp/some/path/dummy_file.ext && touch /tmp/some/path/dummy_file.py
    pushd /tmp/some/
    run_test "No path found" "Some random input" "." "No path found"
    run_test "File not found" "/absolute/path/to/file" "." "default|/absolute/path/to/file|File not found"
    run_test "HTTPS url" "https://www.something.com" "." "url|https://www.something.com|File not found"
    run_test "HTTP url" "http://something.com" "." "url|http://something.com|File not found"
    run_test "WWW url" "www.something.com" "." "url|www.something.com|File not found"
    run_test "Absolute path" "/tmp/some/path/dummy_file.ext" "/tmp/some" "default|/tmp/some/path/dummy_file.ext|File found"
    run_test "Absolute path with wrapping quote marks" "\"/tmp/some/path/dummy_file.ext\"" "/tmp/some" "default|/tmp/some/path/dummy_file.ext|File found"
    run_test "Relative path current dir" "./path/dummy_file.ext" "/tmp/some" "default|/tmp/some/./path/dummy_file.ext|File found"
    run_test "Relative path parent dir" "../path/dummy_file.ext" "/tmp/some/path" "default|/tmp/some/path/../path/dummy_file.ext|File found"
    run_test "Relative path parent dir no file" "../path/dummy_file.no" "/tmp/some/path" "default|/tmp/some/path/../path/dummy_file.no|File not found"
    run_test "Absolute code file:// path" "file:///tmp/some/path/dummy_file.py" "/tmp/some" "code|/tmp/some/path/dummy_file.py|File found"
    run_test "Absolute code file:// path with :line:col suffix" "file:///tmp/some/path/dummy_file.py:50:22" "/tmp/some" "code|/tmp/some/path/dummy_file.py:50:22|File found"
    run_test "Absolute code file:// path with :line:col suffix wrapper in special characters" "some context (file:///tmp/some/path/dummy_file.py:50:22)" "/tmp/some" "code|/tmp/some/path/dummy_file.py:50:22|File found"
    run_test "Relative code file:// path" "file:///path/dummy_file.py" "/tmp/some" "code|/tmp/some/path/dummy_file.py|File found"
    run_test "Relative code file:// path with :line suffix" "file:///path/dummy_file.py:222" "/tmp/some" "code|/tmp/some/path/dummy_file.py:222|File found"
    run_test "Absolute code path with :line:column suffix" "/tmp/some/path/dummy_file.py:22:33" "/tmp/some" "code|/tmp/some/path/dummy_file.py:22:33|File found"
    run_test "Relative code path with :line suffix" "Some console logs ./path/dummy_file.py:222 and more" "/tmp/some" "code|/tmp/some/./path/dummy_file.py:222|File found"
    run_test "Absolute code path with :line:column suffix on multiline input" "Some console
    logs /tmp/some/path/dummy_file.py:22:33
    and more logs on new line" "/tmp/some" "code|/tmp/some/path/dummy_file.py:22:33|File found"
    run_test "Relative code path with :line:column suffix on multiline input" "Some console
    logs ../path/dummy_file.py:22:33
    and more logs on new line" "/tmp/some/path" "code|/tmp/some/path/../path/dummy_file.py:22:33|File found"
    # Cleanup after testing done
    popd
    rm /tmp/some/path/dummy_file.ext
    exit 0
else
    processed_path=$(process_path "$path" $(get_current_dir))
    IFS='|' read -r type path status <<< "$processed_path"
    debug "Final processed path: $path with type: $type and status: $status" >&2

    if [[ "$type" == "No path found" ]]; then
        debug "No path found in the selected input string to open"
        exit 0
    elif [[ "$status" == "File not found" && "$type" != "url" ]]; then
        debug "File $path not found"
        exit 0
    elif [[ "$type" == "url" ]]; then
        if [[ "$path" =~ ^www\. ]]; then
            debug "Detected www URL - adding https:// prefix and opening in Chrome"
            open -a "Google Chrome" "https://$path"
            exit 0
        else
            debug "Detected HTTP/HTTPS URL - opening in Chrome"
            open -a "Google Chrome" "$path"
            exit 0
        fi
    elif [[ "$type" == "code" ]]; then
        debug "Detected code file - opening in Visual Studio Code"
        code -g "$path"
        exit 0
    # default open action
    else
        debug "Detected default file - opening in default app"
        code "$path"
        exit 0
    fi
fi
