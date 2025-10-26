#!/bin/bash

# this script takes a string input and extracts a filepath / url / other
# which is processed, and opened in the appropriate app.
# For example, when you cmd+click a filepath like /my/file.js:55:2
# nothing happens in a terminal like ghostty (no have support yet)
# vs using the vscode terminal emulator which opens the file at line 55, column 2
# when updating the script logic, run the unit tests to make sure nothing breaks via
# echo "run tests" | ./process_path.sh

# IDE Configuration
# Set EDITOR_CMD environment variable to change the IDE
# Examples:
#   export EDITOR_CMD="code"   # VS Code (default)
#   export EDITOR_CMD="cursor" # Cursor
#   export EDITOR_CMD="subl"   # Sublime Text
EDITOR_CMD="${EDITOR_CMD:-code}"

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

normalize_path() {
    local path="$1"
    # Use Python to normalize the path (handles .. and . correctly)
    # Falls back to the original path if Python is not available
    if command -v python3 &> /dev/null; then
        python3 -c "import os; print(os.path.normpath('$path'))" 2>/dev/null || echo "$path"
    else
        echo "$path"
    fi
}

process_path() {
    local multiline_string="$1"
    local current_dir="$2"
    local path
    local type
    local status="File found"

    # Extract the path using grep and regular expressions
    path=$(echo "$multiline_string" | grep -oE "(file:///)?(\.{0,2}/[^[:space:]\"]+|/[^[:space:]\"]+|\w+:\/\/[^[:space:]\"]+)|www\.[^[:space:]\"]+")

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

    # Handle relative paths starting with . or ..
    if [[ "$path" =~ ^\.{1,2}/ ]]; then
        path="$current_dir/$path"
        path=$(normalize_path "$path")
    # If path doesn't exist and doesn't start with /, try prepending current_dir
    # This handles cases like "file:///relative/path" that should be relative to current_dir
    elif [[ ! -e "$path" && ! "$path" =~ ^/ ]]; then
        if [[ -e "$current_dir/$path" ]]; then
            path="$current_dir/$path"
            path=$(normalize_path "$path")
        fi
    # For paths starting with / that don't exist, try as relative to current_dir
    # This handles the file:// case where /path/file might mean current_dir/path/file
    elif [[ ! -e "$path" && "$path" =~ ^/ ]]; then
        if [[ -e "$current_dir$path" ]]; then
            path="$current_dir$path"
            path=$(normalize_path "$path")
        fi
    fi

    # Determine the type of path
    if [[ "$path" =~ ^(http|https|www) ]]; then
        type="url"
    elif [[ "$path" =~ \.(py|sh|js|ts|tsx|jsx|java|c|cpp|go|rs|rb|php|yaml|yml|toml|json|xml|html|css|sql|md|rst|txt|log|conf|cfg|ini|env|gitignore|dockerfile)$ ]]; then
        type="code"
    elif [[ "$path" =~ \.(png|jpg|jpeg|gif|bmp|svg|webp|ico|tiff|tif)$ ]]; then
        type="image"
    elif [[ "$path" =~ \.(pdf|doc|docx|xls|xlsx|ppt|pptx)$ ]]; then
        type="document"
    elif [[ "$path" =~ \.(mp4|mov|avi|mkv|webm|flv|wmv)$ ]]; then
        type="video"
    elif [[ "$path" =~ \.(mp3|wav|flac|aac|ogg|m4a)$ ]]; then
        type="audio"
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
    # Create dummy files and folders for testing
    mkdir -p /tmp/some/path/touch
    touch /tmp/some/path/image.png /tmp/some/path/doc.pdf /tmp/some/path/config.yaml /tmp/some/path/dummy_file.ext /tmp/some/path/dummy_file.py
    pushd /tmp/some/
    run_test "No path found" "Some random input" "." "No path found"
    run_test "File not found" "/absolute/path/to/file" "." "default|/absolute/path/to/file|File not found"
    run_test "HTTPS url" "https://www.something.com" "." "url|https://www.something.com|File not found"
    run_test "HTTP url" "http://something.com" "." "url|http://something.com|File not found"
    run_test "WWW url" "www.something.com" "." "url|www.something.com|File not found"
    run_test "Absolute path" "/tmp/some/path/dummy_file.ext" "/tmp/some" "default|/tmp/some/path/dummy_file.ext|File found"
    run_test "Absolute path with wrapping quote marks" "\"/tmp/some/path/dummy_file.ext\"" "/tmp/some" "default|/tmp/some/path/dummy_file.ext|File found"
    run_test "Relative path current dir" "./path/dummy_file.ext" "/tmp/some" "default|/tmp/some/path/dummy_file.ext|File found"
    run_test "Relative path parent dir" "../path/dummy_file.ext" "/tmp/some/path" "default|/tmp/some/path/dummy_file.ext|File found"
    run_test "Relative path parent dir no file" "../path/dummy_file.no" "/tmp/some/path" "default|/tmp/some/path/dummy_file.no|File not found"
    run_test "Absolute code file:// path" "file:///tmp/some/path/dummy_file.py" "/tmp/some" "code|/tmp/some/path/dummy_file.py|File found"
    run_test "Absolute code file:// path with :line:col suffix" "file:///tmp/some/path/dummy_file.py:50:22" "/tmp/some" "code|/tmp/some/path/dummy_file.py:50:22|File found"
    run_test "Absolute code file:// path with :line:col suffix wrapper in special characters" "some context (file:///tmp/some/path/dummy_file.py:50:22)" "/tmp/some" "code|/tmp/some/path/dummy_file.py:50:22|File found"
    run_test "Relative code file:// path" "file:///path/dummy_file.py" "/tmp/some" "code|/tmp/some/path/dummy_file.py|File found"
    run_test "Relative code file:// path with :line suffix" "file:///path/dummy_file.py:222" "/tmp/some" "code|/tmp/some/path/dummy_file.py:222|File found"
    run_test "Absolute code path with :line:column suffix" "/tmp/some/path/dummy_file.py:22:33" "/tmp/some" "code|/tmp/some/path/dummy_file.py:22:33|File found"
    run_test "Relative code path with :line suffix" "Some console logs ./path/dummy_file.py:222 and more" "/tmp/some" "code|/tmp/some/path/dummy_file.py:222|File found"
    run_test "Absolute code path with :line:column suffix on multiline input" "Some console
    logs /tmp/some/path/dummy_file.py:22:33
    and more logs on new line" "/tmp/some" "code|/tmp/some/path/dummy_file.py:22:33|File found"
    run_test "Relative code path with :line:column suffix on multiline input" "Some console
    logs ../path/dummy_file.py:22:33
    and more logs on new line" "/tmp/some/path" "code|/tmp/some/path/dummy_file.py:22:33|File found"
    run_test "Image file detection" "/tmp/some/path/image.png" "/tmp/some" "image|/tmp/some/path/image.png|File found"
    run_test "Document file detection" "/tmp/some/path/doc.pdf" "/tmp/some" "document|/tmp/some/path/doc.pdf|File found"
    run_test "YAML config file as code" "/tmp/some/path/config.yaml" "/tmp/some" "code|/tmp/some/path/config.yaml|File found"
    run_test "JavaScript file as code" "/tmp/some/path/app.js" "/tmp/some" "code|/tmp/some/path/app.js|File not found"
    run_test "TypeScript JSX file as code" "/tmp/some/path/Component.tsx" "/tmp/some" "code|/tmp/some/path/Component.tsx|File not found"
    # Cleanup after testing done
    popd
    rm -f /tmp/some/path/dummy_file.ext /tmp/some/path/dummy_file.py /tmp/some/path/image.png /tmp/some/path/doc.pdf /tmp/some/path/config.yaml
    rmdir /tmp/some/path/touch 2>/dev/null
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
        debug "Detected code file - opening in $EDITOR_CMD"
        "$EDITOR_CMD" -g "$path"
        exit 0
    elif [[ "$type" == "image" ]]; then
        debug "Detected image file - opening in default image viewer"
        open "$path"
        exit 0
    elif [[ "$type" == "document" ]]; then
        debug "Detected document file - opening in default application"
        open "$path"
        exit 0
    elif [[ "$type" == "video" ]]; then
        debug "Detected video file - opening in default video player"
        open "$path"
        exit 0
    elif [[ "$type" == "audio" ]]; then
        debug "Detected audio file - opening in default audio player"
        open "$path"
        exit 0
    # default open action
    else
        debug "Detected default file - opening in $EDITOR_CMD"
        "$EDITOR_CMD" "$path"
        exit 0
    fi
fi
