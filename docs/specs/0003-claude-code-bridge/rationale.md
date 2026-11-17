# 0003. Claude Code bridge: rationale

The decision record behind [index.md](index.md). `/develop` builds from `index.md`; this file explains why.

## Context

> ⚠️ Premise note: spec [0001](../0001-stack-architecture/rationale.md) already flagged that Verba rests on a coding tool's CLI used as a general model client. This spec makes that bet concrete, and the bet has two specific weak points. First, the cleanest isolation flag, `--safe-mode`, is described by the CLI as a troubleshooting switch, so its meaning can shift between releases. Second, bare mode (`--bare`) ignores the subscription login, and the CLI docs have said it will become the default for `-p`. Neither is a reason to change course, because "no server, no key" is a scope decision. But it does mean the version check, the live tests, and the deferred API key path are part of the design, not extras.

Verba has no server. Every lesson, grade, chat reply, and placement result comes from the Claude Code CLI already installed and signed in on your Mac, started as a child process by the app. Spec 0001 settled the transport (swift-subprocess, an empty `claude-work/` folder, tools and MCP off) and left the details to this spec: the exact flags, how a Finder launched app finds a binary that lives on your shell `PATH`, the minimum CLI version, and what happens when `-p` changes defaults. Spec 0002 settled what the bridge must hand over: a `NewLesson` that checks itself and a `NewGeneration` carrying the prompt version, model, raw reply, and duration.

The forces: the CLI is built for coding, so by default it loads your `CLAUDE.md`, hooks, plugins, MCP servers, and a long coding system prompt, any of which would leak into lessons or change their tone. The app is unsandboxed, so isolation is the bridge's job. Replies come from a language model and are sometimes malformed, so they must be checked before they reach the screen or the database. Failures are normal, not exceptional: the CLI may be missing, outdated, signed out, rate limited by the Pro plan, or slow. And the scope's done line asks that each of those shows a clear message instead of a crash.

The bridge is also the seam every later slice uses: grading (Slice 1), placement (Slice 2), tutor chat with streaming (Slice 3), and memory aware prompts (Slice 4). Swift 6 strict concurrency applies, a child process streams into a live UI, and the project rule is that only `ClaudeBridge` launches processes or builds prompts. Without this decision, feature 6 (the first lesson loop) cannot start, because it has no way to get a lesson.

## Options considered

### Option 1: One isolated headless process per request, schema checked (chosen)

Each request runs `claude -p` once with the isolation flags, a replaced system prompt, and `--json-schema`, reads the single JSON result, and decodes `structured_output`. Streaming calls use the same launch with `stream-json`. The process ends after one reply.

**Pros**:
- Each call is independent: a crash, timeout, or bad reply affects one request, and teardown is just killing one process.
- The CLI checks the reply's shape before Verba sees it; Core then checks its meaning.
- Verified working on the installed 2.1.325 with your subscription login, with an empty working folder afterwards.

**Cons**:
- About 1 second of process and CLI startup per call, which tutor chat will feel on every turn.
- No conversation memory between calls; chat must send its history each turn.

### Option 2: One long lived CLI session fed through stream-json input

Start `claude -p --input-format stream-json --output-format stream-json` once and keep it running, sending each request as a new user message.

**Pros**:
- No startup cost after the first call; natural fit for multi turn chat.
- Prompt caching across turns inside one session.

**Cons**:
- Every request shares one conversation, so lessons would see earlier lessons and chats unless the session is restarted, which brings back the startup cost.
- One stuck or crashed process takes down every feature; recovery, restart, and request matching need a supervisor.
- Per request JSON schema is not available on a running session, so lessons lose the CLI's shape check.

### Option 3: The Claude Agent SDK through a bundled Node or Python helper

Ship a small helper script that uses the official Agent SDK and talk to it over stdin and stdout.

**Pros**:
- A typed, documented programmatic API instead of CLI flags.
- Finer control over sessions, tools, and streaming.

**Cons**:
- Adds a runtime (Node or Python) and a third party dependency the project does not allow without a spec, plus packaging and version management of the helper.
- The SDK runs the same CLI underneath, so the flag and login risks stay.

### Option 4: Free text replies parsed by the app

Run `claude -p --output-format json` without a schema and ask the prompt for JSON, then parse `result` in Swift.

**Pros**:
- Works on older CLI versions without `--json-schema`.
- The simplest call.

**Cons**:
- The model can wrap JSON in prose or code fences, or drift from the shape, and every such reply becomes a retry.
- Duplicates in Swift the shape check the CLI already does.

## Rationale

Option 1 fits the forces best. Isolation is the bridge's job because the app is unsandboxed. A fresh process per call, with no tools, no hooks, no plugins, no MCP, no `CLAUDE.md`, and no saved session, is the smallest surface that delivers it, and it was verified on your installed CLI with your Pro login. The probe used about 1,500 input tokens, which shows the coding system prompt and your customizations were really gone. Schema checked output (`--json-schema`) moves shape errors into the CLI, so Verba's own check is about meaning (Core's `NewLesson` rules), which it needs anyway. Option 2's startup savings matter only for chat, and they cost shared state and a supervisor, the wrong trade for a one person project at Alpha rigor. Chat can revisit this with measured latency. Option 3 adds a runtime and a dependency to solve a problem the CLI already solves. Option 4 gives up the cheapest correctness check available.

The smaller calls follow the same logic. Isolation uses `--safe-mode` over `--restricted` (which keeps file tools) and over hand picked `--setting-sources` (more flags to keep in sync). The status check is lazy and caches only `ready`, so a learner who never opens a lesson pays nothing. A fix made in Terminal (signing in, updating) takes effect on the next call without pressing Check again. And a stale login still surfaces, because every failed call checks again before choosing its message. (The first draft also cached problems. The cross check showed that this traps you after you fix the problem, so it was changed.) The minimum version is the version the flags were verified on, which is strict but honest: an older CLI is untested, not known good. Finding the binary tries your saved path, then the known install folders, then one login shell lookup. That covers the common installs fast, keeps unusual ones (version managers) possible, and the saved path override handles the rest. Usage limits get their own error and no retry, because Pro limits reset over hours, so retrying only burns time.

Some choices are the engineer's own, and this spec records them as decided. The model is a Settings picker (default `sonnet`) rather than a pinned alias. This costs one more control and test, but lets you trade lesson quality against plan usage. It is saved in `UserDefaults` because it is an app preference, not learning data (spec 0001's rule). The bridge reads it through a provider passed in from `AppEnvironment`, so the package never touches global state. The lesson schema leaves out `translate` until feature 6 decides how to grade it. It keeps `fillBlank`, which Core's `Grader` does not grade yet either, so feature 6 must decide that one before Slice 1 ships (recorded in Follow-up).

Decisions made in writing (runner up in parentheses):
- **User message on standard input** (in the arguments): keeps prompt text out of `ps` output and away from argument length limits.
- **Strip `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` from the child environment** (inherit as is): a key would silently switch billing away from the subscription, against the scope's "no key" rule.
- **Build `PATH` from the binary's folder, then the login shell's `PATH` or the Homebrew folders, then the app's own** (leave the GUI `PATH`): an npm install of `claude` is a Node script, and `node` may live beside it (Homebrew) or somewhere only your shell knows (nvm).
- **Error classification by checking the status again after a failed call** (parsing CLI error text for login problems): the status command gives a structured `loggedIn`, while error wording changes between releases.
- **Errors as values on the stream** (a throwing stream): the project passes `AsyncStream`s of `Sendable` values, and typed errors stay intact.
- **One reply shape with optional per kind fields** (a `oneOf` per exercise kind): easier for the model to follow and for the CLI's schema support; the mapper enforces the per kind field, and Core enforces the part rules.
- **Claude writes `reorder` tokens in the correct order and `match` as pairs** (Claude writes positions and keys): fewer ways for the model to get it wrong; the bridge derives `correctPosition` and `matchKey`.
- **Model name from the `modelUsage` key with the most output tokens** (the `--model` alias): records the real model id, for example `claude-haiku-5-5`, which matters when an alias moves to a newer model.
- **`durationMs` measured by the app** (the CLI's `duration_ms`): includes process startup, which is what you actually wait for.
- **Test prompt always on `haiku`** (the chosen model): it proves the connection at the lowest plan cost, and the chosen model is exercised by every lesson anyway.
- **Timeout per attempt, no retry after a timeout** (a shared budget across the retry): a timeout is usually a slow service, and a second 120 seconds rarely helps.

## Evidence: probe of the installed CLI (2026-11-17)

- `claude --version` printed `2.1.325 (Claude Code)`; installed at `~/.local/bin/claude` (a link into `~/.local/share/claude/versions/`).
- `claude auth status --json` returned a JSON object with `loggedIn: true`, `authMethod: "claude.ai"`, `subscriptionType: "pro"`.
- An isolated call from an empty folder with `-p --safe-mode --tools "" --strict-mcp-config --no-session-persistence --disable-slash-commands --system-prompt … --model haiku --output-format json --json-schema '{…"word"…}'`, prompt on stdin, returned `type: "result"`, `subtype: "success"`, `is_error: false`, `api_error_status: null`, `result: "{\"word\":\"ok\"}"`, `structured_output: {"word": "ok"}`, `modelUsage` keyed by `claude-haiku-5-5`, `duration_ms: 1303`; wall time about 2.4 s; about 1,500 input tokens; the folder was still empty afterwards.
- `claude --help` on 2.1.325 lists `--bare` as reading only `ANTHROPIC_API_KEY` or an `apiKeyHelper` (never OAuth or Keychain), and `--safe-mode` as turning off CLAUDE.md, skills, plugins, hooks, MCP servers, and custom agents while keeping auth, model selection, and built in tools working.
