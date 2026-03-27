#!/bin/bash
# Check if the edited file is a .swift file
FILE=$(jq -r '.tool_input.file_path // .tool_response.filePath // ""' 2>/dev/null)
if [[ "$FILE" == *.swift ]]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"A Swift file was just modified. Remember to build via mcp__xcode__BuildProject to verify it compiles."}}'
fi
