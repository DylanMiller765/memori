---
name: verify-changes
description: "Visual verification workflow that runs after every code change to Swift/SwiftUI files. Use this skill after making any edit to the MindRestore codebase — never skip it. Builds via Xcode MCP, captures before/after screenshots when possible, and explains changes to the user. Also use when the user asks to 'show me what changed', 'verify the build', or 'take a screenshot'."
---

# Verify Changes

After every code change, follow this workflow so the user sees exactly what happened.

## Step 1: Build

Build via `mcp__xcode__BuildProject` to confirm the change compiles.

If the build fails:
1. Read the build log with `mcp__xcode__GetBuildLog`
2. Fix the errors
3. Rebuild
4. Repeat until green

## Step 2: Capture screenshots

**If the changed file has a `#Preview` macro:**
- Render the preview with `mcp__xcode__RenderPreview`
- Read the snapshot image and show it to the user

**If no `#Preview` exists:**
- Check if a related component file has a preview (e.g., the parent view, or a share card that uses the changed component)
- If nothing has a preview, note this to the user and suggest adding one for future use
- For critical UI changes without previews, offer to build and run on the simulator as a fallback

**Before/after comparison:**
- When modifying an existing view, capture the preview BEFORE making the change (if you haven't already started editing)
- After the change, capture again and show both to the user so they can compare
- If you already made the change before capturing "before", just show the "after" and describe what was different

## Step 3: Explain the change

Tell the user concisely:
- **What files** were modified
- **What changed** and why
- **What to notice** in the screenshot (if one was captured)

Keep it brief — the user can read the diff. Focus on the *why* and any visual differences.

## When no screenshot is needed

For non-visual changes (services, models, utilities, analytics), still build to verify, but skip the screenshot. Just explain what changed.
