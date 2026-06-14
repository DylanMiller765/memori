# Bug Fix Skill

Systematic bug fix workflow to avoid wrong-approach friction.

## Steps

1. **Read the file(s)** related to the bug thoroughly
2. **Identify the root cause** — check for type mismatches, overflow, nil issues, threading problems
3. **Explain the root cause** to the user BEFORE writing any fix
4. **Write a test** that reproduces the failure (if test target exists)
5. **Implement the fix**
6. **Search for similar patterns** elsewhere in the codebase that might have the same issue
7. **Build and verify** — run `xcodebuild` to confirm the fix compiles
