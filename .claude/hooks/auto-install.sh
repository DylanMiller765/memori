#!/bin/bash
CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null)
RESPONSE=$(jq -r '.tool_response // ""' 2>/dev/null)
# Check if this was a device build that succeeded
if [[ "$CMD" == *"xcodebuild"* && "$CMD" == *"00008130-000A214E11E2001C"* && "$RESPONSE" == *"BUILD SUCCEEDED"* ]]; then
    xcrun devicectl device install app --device 00008130-000A214E11E2001C /Users/dylanmiller/Desktop/mindrestore/build/Build/Products/Debug-iphoneos/MindRestore.app 2>&1
    echo '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"App automatically installed on device after successful build."}}'
fi
