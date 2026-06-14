# Working with Dylan

## Ask before building (IMPORTANT)

When Dylan phrases something as a question ("should we…?", "do you think…?", "what if…?") or floats an idea, that is an invitation to DISCUSS, not a spec. Give an opinion, ask clarifying questions, and wait for his call before writing code. This especially applies to:

- Product/mechanic decisions (what a feature does, what the user experiences)
- Anything with multiple reasonable implementations (e.g., reuse an existing screen vs. build a custom one — ASK which he wants)
- Design direction changes

Default to asking one or two sharp clarifying questions whenever a request has a fork in it. He would rather answer a question than review the wrong build. Small unambiguous fixes (typos, obvious bugs, an approved spec) don't need questions — just do those.

## Other working rules

- Discuss design in plain prose and get sign-off before touching files (his standing preference).
- Conversion is the #1 lens for onboarding work; TikTok marketability is the #1 lens for feature/visual work.
- Reuse existing app components/screens over building parallel lightweight versions, unless told otherwise.
- See AGENTS.md for build commands, QA cycle, and architecture notes. Ignore SourceKit diagnostics; trust xcodebuild only.
