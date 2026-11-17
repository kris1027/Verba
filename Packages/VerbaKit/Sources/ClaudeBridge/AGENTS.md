# ClaudeBridge

## Overview

The infrastructure layer that talks to Claude by running your local `claude` CLI (Claude Code). It implements the `ClaudeConnection` and `LessonWriter` protocols from `Core` through one public actor, `ClaudeCLI`, and it is the only module that launches a process or builds a prompt.

## Key files

| File | Owns |
|---|---|
| `ClaudeCLI.swift` | The public actor: the status cache (one shared check, a generation counter), the test prompt, the lesson call with one retry, and failure classification (AC-11) |
| `ClaudeCLI+Status.swift` | The stateless status probes: find `claude`, read `--version`, check `auth status --json` |
| `ClaudeCLI+Environment.swift` | The pinned argument list, the child environment and `PATH`, and the `claude-work/` folder checks |
| `Runner/CommandRunner.swift` | The `Command`, `CommandOutput`, `CommandError` types and the `CommandRunner` seam tests replace |
| `Runner/SubprocessRunner.swift` | The real runner on swift-subprocess: own session and process group, output limits, time limit, teardown |
| `Status/CLILocator.swift`, `Status/StatusParsing.swift` | Finding the binary (saved path, install folders, one login shell lookup) and parsing version and login output |
| `Call/CLIResult.swift`, `Call/Prompt.swift`, `Call/ReplyProblem.swift` | The CLI's JSON result, versioned prompt loading, and why a reply is unusable |
| `Lesson/` | The `lesson-v1` prompt, its reply type, and the mapper to `Core` values |
| `Resources/Prompts/` | `<name>-vN.system.md`, `.user.md`, `.schema.json` for each prompt version |

## Conventions

- Public API is `ClaudeCLI` only; it throws `Core`'s `ClaudeError`. Subprocess types, `Command*`, `ReplyProblem`, and prompt types stay `internal`.
- Prompts are versioned files: a changed prompt is a new version (`lesson-v2.*`), never an edit to a shipped one. The version is saved with each generation.
- The user message goes on stdin, never in the arguments. Every call runs in the empty `claude-work/` folder with the pinned flags (tools, MCP, slash commands, session saving off) and without `ANTHROPIC_API_KEY` or `ANTHROPIC_AUTH_TOKEN` in its environment.
- Log through `Log.bridge`. Prompts, replies, stderr, error details, and the binary path (it holds your macOS user name) are `privacy: .private`. Only case names (`ClaudeError.caseName`, `CommandError.caseName`), exit status, duration, and model are public.
- Errors are typed enums with one case per reason, never a bare string error.
- Keep stateless helpers in `ClaudeCLI+*.swift` extensions; the actor body sits near SwiftLint's 250 line `type_body_length` limit.
- Tests: `FakeRunner` and `BridgeHarness` (in `Tests/ClaudeBridgeTests/Support/`) for call logic; `ScriptFolder` shell scripts for the real `SubprocessRunner`. The search paths and shell lookup are always injected so your real `claude` never leaks into a test.
- Live tests against the real CLI are off by default: `VERBA_LIVE_CLAUDE=1 swift test --package-path Packages/VerbaKit --filter LiveClaudeTests` (uses a little of your plan). Run them after installing a Claude Code update.

## Gotchas

- swift-subprocess always appends a final SIGKILL to the teardown sequence and sends it to the group when the last configured step did, so only the SIGTERM step is written out.
- `SubprocessRunner` ignores `SIGPIPE` for the whole process, so writing to a child that already exited is a returned error, not a crash.
- A typed throws `Task` closure crashes the Swift 6.4 compiler; carry the error in a `Result` instead.
- `ClaudeCLI.minimumVersion` is the oldest Claude Code whose flags were verified; raise it when the pinned flags change.

## Related specs

- [0001 Stack & architecture](../../../../docs/specs/0001-stack-architecture/index.md)
- [0003 Claude Code bridge](../../../../docs/specs/0003-claude-code-bridge/index.md)

_Drafted by /sync from the introducing change, worth a quick human pass._
