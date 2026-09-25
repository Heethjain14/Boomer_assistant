# Working in this repo

## Branch naming

Don't name branches with a `claude/...` prefix or otherwise reference
Claude/Anthropic in the name. GitHub's Claude App integration can attach a
ruleset to `claude/**`-pattern branches that blocks deletion, which is
awkward for a personal project where branches get cleaned up regularly.

Use short, plain, descriptive names instead — e.g. `windows-support`,
`fix-send-timeout`, `docs-update`. If work needs its own branch, ask what to
call it rather than defaulting to an auto-generated `claude/...` name.
