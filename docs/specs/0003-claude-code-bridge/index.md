# 0003. Claude Code bridge: one isolated, schema checked CLI call per request

**Date**: 2026-11-17
**Status**: Accepted

## Summary

This spec decides how Verba talks to Claude. Every request starts the local `claude` command line tool once, in an empty folder, with tools, hooks, plugins, and MCP servers turned off, and asks for a reply that must match a JSON schema (a strict description of the reply's shape). The bridge checks the reply again against Core's lesson rules, retries once if it is unusable, and turns every failure (not installed, too old, signed out, plan limit, timeout) into a clear message. For building, this means Core gets two small service protocols and one error enum; `ClaudeBridge` gets a process runner, a CLI finder with a status check, a test prompt, and the first real call (write a lesson); and Settings gets a **Claude** section that shows the status, a model picker, and a **Send test prompt** button.

## Requirements

**User stories**:
- As a learner, I want Verba to write a lesson for my language pair through my own Claude Code login, so that I need no server and no API key.
- As a learner, I want a clear, fixable message when Claude Code is missing, out of date, signed out, or out of plan usage, so that I know what to do instead of watching the app hang or crash.
- As a learner, I want to choose which Claude model teaches me, so that I can trade quality against plan usage.
- As the builder of later slices, I want one tested client with pinned flags and typed errors, so that grading, chat, and placement only add a prompt and a reply type.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: The bridge finds `claude` in this order and uses the first hit that is an executable file: (1) the path saved in Settings, if set; (2) `~/.local/bin/claude`, `~/.claude/local/claude`, `/opt/homebrew/bin/claude`, `/usr/local/bin/claude`; (3) the output of one `/bin/zsh -lc 'command -v claude'` run (5 second limit, only the last non empty output line is used, and it must be an absolute path to an executable file). A saved path that is not an executable file gives `ClaudeError.customPathInvalid` and does not fall back to the automatic search. Nothing found gives `ClaudeError.notInstalled`.
- **AC-2**: The status check runs `claude --version` and reads the first `MAJOR.MINOR.PATCH` match, compared as a triple of integers (any suffix such as `-beta` is ignored; `found` is the matched triple). A version below **2.1.325** gives `ClaudeError.versionTooOld(found:minimum:)`. A non zero exit or output with no readable version gives `ClaudeError.versionUnreadable`. Newer versions pass.
- **AC-3**: The status check runs `claude auth status --json` and reads `loggedIn` from stdout whenever stdout is JSON, whatever the exit status. `false` gives `ClaudeError.notLoggedIn`. Stdout that is not JSON or has no `loggedIn` gives `ClaudeError.failed`. When every step passes, the status is `ready` with the version and the resolved path.
- **AC-4**: The status check is lazy, and only a `ready` result is cached: it runs on the first Claude call or when the Settings **Claude** section appears, and later calls reuse a cached `ready`. A `problem` is never cached, so every call checks again while something is wrong (signing in from Terminal fixes the next call without **Check again**). **Check again**, a change of the saved path, and any AC-11 failure clear the cache. Calls that need the status at the same time share one check.
- **AC-5**: Every Claude call runs the resolved binary with exactly these arguments, in this order: `-p --safe-mode --tools "" --strict-mcp-config --disable-slash-commands --no-session-persistence --output-format json --model <alias> --system-prompt <system text> --json-schema <schema text>`. The working directory is the data folder's `claude-work/`. The user message goes in on standard input, never in the arguments. The child environment is the app's environment without `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN`, with `PATH` set to: the directory that holds the found `claude`, then the login shell's `PATH` if the shell lookup (AC-1 step 3) ran, else `/opt/homebrew/bin:/usr/local/bin`, then the app's own `PATH` (duplicates removed, order kept). The bridge never deletes anything in `claude-work/`; if it holds any file after a call, the bridge logs a public warning. In the live test it is empty after a call.
- **AC-6**: `LessonWriter.writeLesson(_:)` returns a `GeneratedLesson` whose `NewLesson` has the request's `courseID`, kind `regular`, a title, a topic, a Markdown explanation, and 4 to 6 exercises using only `choice`, `fillBlank`, `reorder`, and `match`, and passes `NewLesson.validate()`. Its `NewGeneration` has kind `lesson`, `promptVersion` `lesson-v1`, the model name the CLI reported (nil when `modelUsage` is missing or empty), `rawReply` equal to the CLI's `result` text when it is not empty (else `structured_output` encoded again with sorted keys), and `durationMs` measured by the app for the successful attempt. The prompt names the native language as the language of every explanation and instruction, and the target language as the language being taught.
- **AC-7**: Reply mapping follows *Lesson reply schema*: a `choice` becomes one part per option with its `isCorrect`; a `fillBlank` becomes one part per accepted answer with `isCorrect` true; a `reorder` becomes one part per token, in the order given, with `correctPosition` equal to its index; a `match` becomes two parts per pair (left, then right) sharing the key `p<pairIndex>`. Part order in Claude's reply becomes `sourcePosition`; the bridge never shuffles. An exercise `explanation` that is empty after trimming becomes nil.
- **AC-8**: A successful result (`is_error` false, exit 0) is unusable when it has no `structured_output`; does not decode into the reply type (including any exercise kind outside the four, such as `translate`); has an exercise missing the field its kind needs; has fewer than 4 or more than 6 exercises; has a `choice` with other than 3 or 4 options or other than exactly one correct option; has a required string that is empty after trimming or longer than the schema's limit; or fails `NewLesson` validation (the mapper catches the `ValidationError`). An unusable reply is retried once automatically with the same request. If the second reply is also unusable, the call throws `ClaudeError.invalidReply(reason:)` with the reason from the second reply. Each unusable raw reply is logged with `privacy: .private` and never saved. Error results are not retried here; they follow AC-10 and AC-11.
- **AC-9**: The 120 second limit applies to each attempt's CLI process; the retry starts a fresh clock, and status checks do not count toward it. A lesson attempt still running after 120 seconds is stopped (SIGTERM, then SIGKILL 2 seconds later) and throws `ClaudeError.timedOut(seconds: 120)`; a timeout is not retried. Cancelling the calling task stops the process the same way and throws `ClaudeError.cancelled`; a cancel that arrives between the first attempt and the retry throws `cancelled` without starting the retry. The call returns only after teardown has finished, so no `claude` process started by the bridge is still alive.
- **AC-10**: A result with `api_error_status` 429, or whose error text contains "usage limit" or "rate limit" (any case), throws `ClaudeError.usageLimitReached`, is not retried, and does not clear the status cache.
- **AC-11**: Failures are classified in this order: cancelled (AC-9), timed out (AC-9), usage limit (AC-10), then this rule. Any other failed call (process launch failure, non zero exit, stdout over its size limit or not one JSON object, or `is_error` true) clears the status cache and runs the status check again once (a check that runs because of this rule never starts another one, and concurrent failures share one check). If the check now reports a problem (`notInstalled`, `customPathInvalid`, `versionTooOld`, `versionUnreadable`, `notLoggedIn`), the call throws that problem; otherwise it throws `ClaudeError.failed(reason:)`. The CLI's standard error and result text go only to the private log.
- **AC-12**: Settings has a **Claude** section showing: the status line (`Ready, Claude Code <version>`, a progress indicator while checking, or the `ClaudeError` message); the path in use with **Choose…** and **Use automatic** controls; a **Model** picker (Sonnet, Opus, Haiku); and a **Check again** button. Every `ClaudeError` case has its own plain `errorDescription` that says what to do. Every control has an accessibility label, the section works with Dynamic Type and VoiceOver in reading order, and text meets WCAG AA contrast.
- **AC-13**: **Send test prompt** runs one structured call through the same runner and flags (model `haiku`, 30 second limit, schema `{"reply": string}`) and shows `Reply received in <seconds> s from <model>` on success, or the `ClaudeError` message on failure. The button is disabled while a test runs.
- **AC-14**: The model choice is saved in `UserDefaults` under `claude.model` (values `sonnet`, `opus`, `haiku`; missing or unknown means `sonnet`) and is passed as `--model` on every lesson call, read at the start of each call. The saved path lives under `claude.cliPath`.
- **AC-15**: Prompts, replies, the topic hint, the CLI's standard error, and the binary path (it contains your macOS user name) are logged through `Log.bridge` only with `privacy: .private`. Argument names, exit status, duration, model, and error case are logged as public.
- **AC-16**: For each accepted `choice` exercise whose longest option has more than twice the `Character` count of its shortest (options are never empty here, AC-8), the bridge logs a public warning with the exercise position and still accepts the lesson.

## Decision

**Chosen option**: Option 1: one isolated headless CLI process per request, with schema checked structured output.

Each request launches `claude -p` once with the pinned isolation flags and a JSON schema, decodes `structured_output` into a private reply type, maps it into Core values that check themselves, and reports every failure as a typed `ClaudeError`; tutor chat later adds a streaming variant of the same runner.

**Implementation skills**: `swift-concurrency` (`avdlee/swift-concurrency-agent-skill`, `.agents/skills/swift-concurrency/`) · `swift-testing-pro` (`twostraws/swift-testing-agent-skill`, `.agents/skills/swift-testing-pro/`) · `swiftui-pro` (`twostraws/swiftui-agent-skill`, `.agents/skills/swiftui-pro/`)

## Rationale

Reasoning and options: see [rationale.md](rationale.md).

## Feature design

### Module map

| Piece | Module | Visibility | Role |
|---|---|---|---|
| `ClaudeError`, `ClaudeModel`, `ClaudePreferences`, `ClaudeStatus`, `TestReply` | Core | public | Values every side shares. |
| `ClaudeConnection` (status, test prompt) | Core | public protocol | Used by the Settings model. |
| `LessonWriter`, `LessonRequest`, `GeneratedLesson` | Core | public | Used by feature 6's lesson model, which then calls `LessonStore.saveGeneratedLesson`. |
| `ClaudeCLI` (actor) | ClaudeBridge | public | Implements `ClaudeConnection` and `LessonWriter`. Holds the status cache. |
| `CommandRunner` protocol, `SubprocessRunner` | ClaudeBridge | internal | The seam: run a program with arguments, stdin, cwd, env, and a time limit; return stdout, stderr, exit status. |
| `CLILocator`, `CLIResult`, `LessonReply`, `LessonPrompt` | ClaudeBridge | internal | Find the binary, decode the CLI's JSON, the reply type, build the prompt from resources. |
| `ClaudeSettingsModel` + the **Claude** section of `SettingsView` | Features | public | Orchestrates the status check, test prompt, path, and model. |
| Wiring | App (`AppEnvironment`) | internal | Builds one `ClaudeCLI` with `paths`, a `SubprocessRunner`, and a preferences provider; hands it to Settings through `@Environment`. |

The bridge does not touch the database. Feature 6's model calls `writeLesson`, then `saveGeneratedLesson(_:generation:)` from spec [0002](../0002-data-model/index.md).

**Data model sketch**:

No database change and no migration. New Core value types:

- `ClaudeModel`: enum `sonnet`, `opus`, `haiku` (raw values are the CLI aliases). `static let defaultModel = .sonnet`.
- `ClaudePreferences`: `model: ClaudeModel`, `cliPath: URL?`. `static let modelKey = "claude.model"`, `static let cliPathKey = "claude.cliPath"` (shared by the bridge's provider and the Settings `@AppStorage`). The path is saved as a plain path `String`; a missing or empty string means automatic, and the provider builds the URL with `URL(filePath:)`. **Use automatic** removes the key.
- Every new Core type is `Sendable` and `Hashable` and has a public, documented initializer (the bridge builds `GeneratedLesson`, `TestReply`, and `ClaudeStatus`; tests build all of them).
- `ClaudeStatus`: enum `ready(version: String, path: URL)`, `problem(ClaudeError)`.
- `TestReply`: `model: String`, `durationMs: Int`.
- `LessonRequest`: `courseID: CourseID`, `nativeLanguage: LanguageTag`, `targetLanguage: LanguageTag`, `topicHint: String?`. The init trims the hint, turns an empty hint into nil, and throws `ValidationError.invalidTopicHint` for a hint over 200 characters or containing a line break.
- `GeneratedLesson`: `lesson: NewLesson`, `generation: NewGeneration`.
- `ClaudeError` (typed, `Sendable`, `Hashable`, `LocalizedError`):

| Case | `errorDescription` |
|---|---|
| `notInstalled` | "Verba couldn't find Claude Code. Install it from claude.com/claude-code, or choose where it is in Settings > Claude." |
| `customPathInvalid(path: String)` | "The Claude Code path in Settings isn't a program Verba can run. Choose it again or use automatic." |
| `versionTooOld(found: String, minimum: String)` | "Claude Code \(found) is too old. Verba needs \(minimum) or newer. Run `claude update` in Terminal." |
| `versionUnreadable` | "Verba couldn't read which version of Claude Code is installed. Check that `claude --version` works in Terminal." |
| `notLoggedIn` | "Claude Code isn't signed in. Open Terminal, run `claude`, and sign in with your Claude account." |
| `usageLimitReached` | "You've reached your Claude plan's usage limit. Try again later." |
| `timedOut(seconds: Int)` | "Claude didn't answer within \(seconds) seconds. Try again." |
| `cancelled` | "The request to Claude was stopped." |
| `invalidReply(reason: String)` | "Claude sent a reply Verba couldn't use. Try again." (the reason goes to the log only) |
| `failed(reason: String)` | "Claude Code stopped with an error. Try again, or use Check again in Settings > Claude." (the reason goes to the log only) |

`ValidationError` gains `invalidTopicHint` ("A topic hint must be one line of 200 characters or fewer.").

**State transitions**:

The status cache inside `ClaudeCLI`: `unknown` → `checking` (one in flight unstructured `Task`, awaited through `task.value` by every caller, so one caller's cancellation never cancels the shared check) → `ready(version, path)` is stored; a `problem(error)` is returned to the waiting callers and the cache goes back to `unknown`. `invalidate()` (Check again, a saved path change, or an AC-11 failure) → `unknown` and bumps a generation counter; a check stores its result only if the counter has not changed since it started. A call that gets `problem` from the check throws that error without launching the CLI (`ClaudeStatus.requireReady() throws(ClaudeError) -> (version: String, path: URL)` does the unwrap).

**API surface** (Swift calls, not HTTP; all local, no auth):

| Call | Kind | Key inputs | Key outputs | Key errors |
|---|---|---|---|---|
| `ClaudeConnection.status(refresh: Bool) async -> ClaudeStatus` | read, cached | `refresh` true clears the cache first | `ready(version, path)` or `problem(error)` | (none thrown; problems are values) |
| `ClaudeConnection.sendTestPrompt() async throws(ClaudeError) -> TestReply` | one CLI call | (none; model `haiku`, 30 s) | model name, duration | every `ClaudeError` |
| `LessonWriter.writeLesson(_ request: LessonRequest) async throws(ClaudeError) -> GeneratedLesson` | one CLI call, up to one retry | `LessonRequest` | `NewLesson` + `NewGeneration` | `invalidReply`, `timedOut`, `usageLimitReached`, `cancelled`, a status problem, `failed` |
| `CommandRunner.run(_ command: Command) async throws(CommandError) -> CommandOutput` (internal) | process | `Command`: executable URL, arguments, stdin text (nil means stdin closed), cwd, env, `timeLimit: Duration` | `CommandOutput(stdout: Data, stderr: Data, exitStatus: Int32, stdoutTruncated: Bool)` for every exit, zero or not | `CommandError.launchFailed(String)`, `.timedOut`, `.cancelled` (internal enum) |

`ClaudeCLI` maps `CommandError`: `launchFailed` goes to AC-11, `timedOut` becomes `ClaudeError.timedOut(seconds:)`, `cancelled` becomes `ClaudeError.cancelled`. Inside the time limit task group, results travel as `Result<CommandOutput, CommandError>` (typed throws do not infer well through task groups), and the timer child sets a flag so the runner knows whether the timer or the caller's cancellation won.

`ClaudeCLI.init(paths: AppPaths, runner: any CommandRunner, preferences: @escaping @Sendable () -> ClaudePreferences, searchPaths: [URL] = CLILocator.defaultSearchPaths(home: .homeDirectory), shellLookup: @escaping @Sendable () async -> ShellLookup? = CLILocator.loginShellLookup)`, where `ShellLookup` holds the found path and the login shell's `PATH` (the lookup runs `/bin/zsh -lc 'command -v claude; printf "%s" "$PATH" >&2'` with stdin closed). Tests pass their own search list and lookup so the developer's real `~/.local/bin/claude` never leaks in. If `claude-work/` is missing at call time, the bridge creates it (`AppPaths.prepareFolders()`), and a failure there becomes `failed`.

**CLI call contract** (pinned, verified on Claude Code 2.1.325):

- Arguments as in AC-5. `--safe-mode` turns off `CLAUDE.md`, skills, plugins, hooks, MCP servers, custom agents, and output styles while keeping the subscription login. `--tools ""` removes every built in tool. `--strict-mcp-config` without `--mcp-config` loads no MCP server. `--no-session-persistence` keeps lessons out of your `claude --resume` list. `--system-prompt` replaces Claude Code's coding prompt with Verba's.
- Never pass `--bare`: it reads only `ANTHROPIC_API_KEY` and skips the subscription login.
- Status commands: `claude --version` and `claude auth status --json`, each with a 10 second limit, same cwd and environment.
- Output limits: stdout is collected up to 4 MiB (more sets `stdoutTruncated`, which counts as an AC-11 failure); stderr up to 64 KiB, cut off silently and decoded as UTF-8 with invalid bytes replaced. Stdout is decoded as `Data` straight into `JSONDecoder` after trimming surrounding whitespace; anything else before or after the one JSON object counts as an AC-11 failure (the live test confirms no notice is printed in `-p` mode).
- Read from the single JSON object on stdout: `type` (must be `result`), `subtype`, `is_error` (wins over everything else: `is_error` true is an error even if `structured_output` is present), `api_error_status`, `result` (string), `structured_output` (object), and `modelUsage` (object keyed by model name; the model is the key with the most output tokens, ties going to the alphabetically first key, nil if missing or empty). Unknown fields are ignored.
- Writing stdin to a child that has already exited is a returned failure (AC-11), never a crash.
- Launch through swift-subprocess with the teardown sequence SIGTERM, then SIGKILL after 2 seconds, used for both timeout and task cancellation, and await the teardown before returning. Start the child in its own process group when swift-subprocess's platform options allow it, and send the signals to the group, so a Node wrapper's own children stop too; if the library cannot do that, only the direct child is signalled (see Consequences).
- Resources: `Sources/ClaudeBridge/Resources/Prompts/` holds `lesson-v1.system.md`, `lesson-v1.user.md`, `lesson-v1.schema.json`, `test-v1.system.md`, `test-v1.user.md`, and `test-v1.schema.json`, declared in `Package.swift` with `resources: [.copy("Resources/Prompts")]` and read with `Bundle.module.url(forResource: "<stem>.<part>", withExtension: "md" or "json", subdirectory: "Prompts")`. The file stem is the `promptVersion`. A changed prompt is a new file (`lesson-v2.*`), never an edit to a shipped version. The test prompt is "Reply with the word ready." under a one line system text; any reply that decodes as `{"reply": string}` passes.
- Templates: placeholders `{{name}}` are replaced in one left to right pass over the template text, with no second expansion, so a value containing `{{` stays literal. Inside the quoted topic hint, `"` becomes `'`.

**Lesson prompt** (`lesson-v1`):

- System text: Verba's teacher role and the teaching principles that apply to one lesson: explain one small thing simply, then drill it with effortful recall; write every explanation, instruction, and exercise prompt in the native language, and the material being learned in the target language; one clear idea per lesson, finishable in one sitting; for `choice`, 3 or 4 options of similar length with exactly one correct; for `fillBlank`, mark the gap in the prompt with `___` and list every accepted answer; never rely on option order.
- User text template: placeholders `{{nativeLanguage}}`, `{{targetLanguage}}`, and `{{topicLine}}`. Languages are written as the English name plus the tag, for example `Polish (pl)`, using `Locale(identifier: "en").localizedString(forIdentifier:)`, falling back to the tag alone. `{{topicLine}}` is `Topic requested by the learner: "<hint>"` when a hint exists, else `Choose a useful topic for a beginner.`

**Lesson reply schema** (`lesson-v1.schema.json`, `additionalProperties: false` on every object):

```json
{
  "title": "string, 1 to 80 chars",
  "topic": "string, 1 to 40 chars",
  "explanation": "string, Markdown, 1 to 3000 chars",
  "exercises": [ /* 4 to 6 items */ {
    "kind": "choice | fillBlank | reorder | match",
    "prompt": "string",
    "explanation": "string",
    "choices": [ { "text": "string", "isCorrect": true } ],
    "answers": [ "string" ],
    "tokens": [ "string, in the correct order" ],
    "pairs": [ { "left": "string", "right": "string" } ]
  } ]
}
```

Only `kind`, `prompt`, and `explanation` are required on an exercise; the kind's own field (`choices`, `answers`, `tokens`, or `pairs`) is checked by the mapper, and a missing one counts as an unusable reply (AC-8). Fields that do not belong to the kind are ignored. `LessonReply`'s kind is a private four case enum, so `translate` (valid in Core) fails to decode. The mapper itself enforces every limit in AC-8 (counts, exactly one correct choice, string lengths), because the CLI's schema check is not relied on for limits and Core's `validate()` allows more than one correct option. A schema test decodes a sample reply for every kind and asserts the schema file and `LessonReply` agree on every field name.

**Streaming contract** (designed now, built with tutor chat, feature 10):

- Arguments: the AC-5 set with `--output-format stream-json --verbose --include-partial-messages` in place of `--output-format json`, and no `--json-schema`.
- Internal API: `CommandRunner.stream(_:) -> AsyncStream<CommandEvent>` yielding stdout lines; `ClaudeCLI` maps them into `AsyncStream<ClaudeStreamEvent>` with `.text(String)` for each text delta, `.finished(model: String?, durationMs: Int, rawReply: String)` from the final `result` event, and `.failed(ClaudeError)` (the stream finishes after `.finished` or `.failed`). Errors travel as an event because the project passes `AsyncStream`s of `Sendable` values, not throwing streams. Cancelling the consumer stops the process with the same teardown.
- The exact partial message event names must be confirmed against the installed CLI when feature 10 builds it. The Core protocol (`ChatReplier` or similar) is named by the tutor chat spec.

**Value sourcing**:

| Action | Value produced / displayed | Source |
|---|---|---|
| `writeLesson` | native and target language in the prompt | `LessonRequest.nativeLanguage` / `targetLanguage` (feature 6 fills them from `Course`) |
| `writeLesson` | topic line | `LessonRequest.topicHint`, else the fixed beginner sentence |
| `writeLesson` | `--model` | `ClaudePreferences.model`, from the provider closure reading `UserDefaults` key `claude.model` at call start |
| `writeLesson` | `courseID`, lesson `kind` | `LessonRequest.courseID`; `kind` is always `regular` |
| `writeLesson` | lesson, exercise, and part ids | Core initializer defaults (new UUIDs), built in the bridge mapper |
| `writeLesson` | title, topic, explanation, prompts, part texts, `isCorrect`, `correctPosition`, `matchKey` | `structured_output`, mapped per AC-7 |
| `writeLesson` | `NewGeneration.kind` / `promptVersion` | constant `lesson` / resource file stem `lesson-v1` |
| `writeLesson` | `NewGeneration.model` | the `modelUsage` key with the most output tokens (ties: alphabetically first; nil if none) |
| `writeLesson` | `NewGeneration.rawReply` | the CLI JSON's `result` string as received; if empty, `structured_output` encoded again with sorted keys |
| `writeLesson` | `invalidReply` reason | the mapper's reason for the second unusable reply (decode error, rule, or the caught `ValidationError` description) |
| child `PATH` | folders | found binary's folder, then `ShellLookup`'s `PATH` or `/opt/homebrew/bin:/usr/local/bin`, then `ProcessInfo` `PATH` |
| `writeLesson` | `NewGeneration.durationMs` | `ContinuousClock` measured around the successful attempt's process run, in milliseconds |
| `status` | version | `claude --version` stdout, first `MAJOR.MINOR.PATCH` match |
| `status` | path in use | `CLILocator` result (saved path, known path, or shell lookup) |
| `status` | signed in | `claude auth status --json` `loggedIn` |
| `status` | minimum version | constant `2.1.325` in `ClaudeCLI` |
| `sendTestPrompt` | seconds shown | `TestReply.durationMs` / 1000, one decimal |
| `sendTestPrompt` | model shown | the `modelUsage` key, else "Claude" |
| Settings | saved path / model | `@AppStorage(ClaudePreferences.cliPathKey)` (a `String`, empty means automatic) / `(.modelKey)`; a path change calls `status(refresh: true)` from `onChange` |
| any failure | message shown | `ClaudeError.errorDescription` |

**Key invariants**:

- Only `ClaudeBridge` launches a process or builds a prompt (existing SwiftLint rules). Features never see a prompt, a flag, or CLI JSON.
- Every call uses the AC-5 argument set; no code path builds a different list except the documented streaming variant and the two status commands.
- The bridge never shuffles and never saves; the app shuffles at display time (spec 0002), and the feature model saves.
- A `GeneratedLesson` always holds a `NewLesson` that passed `validate()`.
- `ClaudeCLI` is an `actor`; it holds only the status cache, its generation counter, and the in flight check `Task`. It has no global lock: calls run in parallel, and each feature model allows one call of its own at a time.
- The bridge never reads `UserDefaults` directly; it calls the `@Sendable () -> ClaudePreferences` provider the app passed in.
- Every thrown error from a public bridge call is a `ClaudeError`; no `try?` swallows a failure.

**Security model**:

Single local user, no server. The child runs as your macOS user with your Claude Code login; Verba never reads, stores, or forwards credentials, and it strips API key variables so a stray key can never switch billing. Isolation replaces the App Sandbox (spec 0001): an empty working folder, no tools, no MCP, no hooks, no plugins, no `CLAUDE.md`, no saved session. What leaves the Mac: the prompt text (language names, the optional topic hint), sent to Anthropic by the CLI under your plan's terms. Prompts and replies are learning content and are logged only as private. The topic hint is your own text in your own prompt; the prompt frames it as a topic only, and since there are no tools, a hostile hint can at worst produce a bad lesson, which validation catches.

**Configuration required**:

- No environment variables or secrets. Prerequisite on the Mac: Claude Code 2.1.325 or newer, signed in with a Claude subscription.
- `UserDefaults` keys `claude.model` and `claude.cliPath` (app preferences, not learning data).
- Opt in live tests: `VERBA_LIVE_CLAUDE=1` in the environment of `swift test`.

**Testing approach**:

- Parsing, mapping, retry, and error classification run against a fake `CommandRunner` that returns canned `CommandOutput`s (no process).
- Real process paths use small fake `claude` shell scripts written into a temp folder by the test (print canned JSON, exit with a code, sleep past the limit, print the received args and stdin, touch a file in cwd).
- One live test suite, enabled only when `VERBA_LIVE_CLAUDE=1`, runs the real status check, the test prompt, and one lesson call on `haiku`.
- `FeaturesTests` get `FakeClaudeConnection` and `FakeLessonWriter` with the same contract.

**Critical test scenarios** (each maps to an acceptance criterion in ## Requirements):
- Locator: a saved executable path wins; a saved non executable path gives `customPathInvalid` without searching; an empty search list plus a shell script printing noise then a path uses the last line; nothing found gives `notInstalled`, verifies **AC-1**
- Version: `2.1.325 (Claude Code)` and `2.2.0` pass, `2.1.324` gives `versionTooOld`, `hello` gives `versionUnreadable`, verifies **AC-2**
- Auth: `{"loggedIn": false}` gives `notLoggedIn`; non JSON gives `failed`, verifies **AC-3**
- Cache: two concurrent `status()` calls run the fake runner's version command once; `refresh: true` runs it again; a `problem` result is not cached (the next call checks again); an `invalidate()` during a check stops that check's result from being stored; cancelling one waiting caller does not cancel the other's check, verifies **AC-4**
- Isolation: a fake script that echoes its arguments, cwd, stdin, and `ANTHROPIC_API_KEY` shows the exact AC-5 list, `claude-work/` as cwd, the message on stdin, and no key; the folder is empty afterwards in the live test, verifies **AC-5**
- Happy path: a canned valid reply with one exercise of each of the four kinds maps to a `NewLesson` that validates and a `NewGeneration` with `lesson-v1`, the model, the raw `result`, and a positive duration; the live test does the same against real Claude, verifies **AC-6**, **AC-7**
- Bad reply: first reply has a `reorder` with no `tokens`, second is valid, so the call succeeds after exactly two runs; two bad replies give `invalidReply` after exactly two runs; 3 exercises, a `translate` exercise, a choice with two correct options, and an 81 character title each count as bad; an `is_error` result is not retried, verifies **AC-8**
- Output limits: a fake script printing 5 MiB of stdout, or a notice line before the JSON, gives the AC-11 path; non UTF-8 stderr does not crash, verifies **AC-11**
- Timeout and cancel: a fake script that sleeps 300 s with a 1 s test limit gives `timedOut` and its pid is gone when the call returns; cancelling the task gives `cancelled` and its pid is gone; cancelling after a bad first reply gives `cancelled` with exactly one run, verifies **AC-9**
- Plan limit: `api_error_status: 429` gives `usageLimitReached` after exactly one run, verifies **AC-10**
- Failure classification: exit 1 followed by a status check reporting `loggedIn: false` gives `notLoggedIn`; exit 1 with a healthy status gives `failed`; two concurrent failing calls run one shared status check; a 429 result runs no status check, verifies **AC-10**, **AC-11**
- Environment: the echo script shows `PATH` starting with the binary's folder, then the shell lookup's `PATH` (or the two Homebrew folders when no lookup ran), verifies **AC-5**
- Settings: the model shows each status and error message; every `ClaudeError` case has a non empty description; UI check of labels and Dynamic Type during `/check verify`, verifies **AC-12**
- Test prompt: fake runner returns a valid test reply, the model shows the formatted line; the button is disabled while running, verifies **AC-13**
- Preferences: an unknown `claude.model` value passes `--model sonnet`; `opus` passes `--model opus`, verifies **AC-14**
- Logging and fair options: a choice with options `a` and `a very long option` logs the warning and still returns the lesson; log calls for content use private, checked by review, verifies **AC-15**, **AC-16**
- Auth/permission: not applicable (single local user); the "no API key" rule is covered by the isolation scenario, verifies **AC-5**

## Build plan

Tracer Bullet: tasks 1 to 4 build the thinnest real thread (Settings → `ClaudeCLI` → the real CLI → a message on screen) with the test prompt; tasks 5 and 6 thicken it with the lesson call that feature 6 will use. Streaming is designed above and built with feature 10.

1. Core: `ClaudeError` (with messages), `ClaudeModel`, `ClaudePreferences` (with keys), `ClaudeStatus`, `TestReply`, `LessonRequest` (with `ValidationError.invalidTopicHint`), `GeneratedLesson`, and the `ClaudeConnection` and `LessonWriter` protocols, all with `///` docs; `CoreTests` for `LessonRequest` and every error message; `FakeClaudeConnection` and `FakeLessonWriter` in `FeaturesTests`, satisfies **AC-12**, **AC-14**
2. ClaudeBridge runner: `Command`, `CommandOutput`, `CommandError`, `CommandRunner`, and `SubprocessRunner` (stdin, cwd, environment with API keys removed and the AC-5 `PATH`, output limits, time limit race with the winner flag, process group when available, SIGTERM then SIGKILL teardown awaited, cancellation), with fake script tests; replaces the placeholder in `ClaudeBridge.swift`, satisfies **AC-5**, **AC-9**
3. ClaudeBridge status: `CLILocator` (injectable search paths and shell lookup), version parsing with the 2.1.325 minimum, `auth status` parsing, and the `ClaudeCLI.status(refresh:)` actor state (only `ready` cached, generation counter, shared unstructured check task); `CLIResult` decoding and the shared error classification in AC-11 order, satisfies **AC-1**, **AC-2**, **AC-3**, **AC-4**, **AC-10**, **AC-11**, **AC-15**
4. Thin thread end to end: `test-v1` system, user, and schema resources, `sendTestPrompt()`, `AppEnvironment` builds one `ClaudeCLI` (paths, `SubprocessRunner`, a provider reading `UserDefaults.standard`) and passes it in through `@Environment`; `ClaudeSettingsModel` and the **Claude** section in `SettingsView` (status, path chooser with `fileImporter` and **Use automatic**, model picker, **Check again**, **Send test prompt**), accessible; Settings window sized to fit, satisfies **AC-5**, **AC-12**, **AC-13**, **AC-14**
5. Lesson call: `lesson-v1` system, user, and schema resources; `LessonPrompt`; `LessonReply` decoding; the mapper into `NewLesson` per kind; the one retry; the fair options warning; the schema to type agreement test, satisfies **AC-6**, **AC-7**, **AC-8**, **AC-10**, **AC-16**
6. Live test suite behind `VERBA_LIVE_CLAUDE=1` (status, test prompt, one `haiku` lesson that validates, `claude-work/` empty afterwards), and a manual run of **Send test prompt** from the built app, satisfies **AC-5**, **AC-6**, **AC-13**

## Consequences

**Positive**:
- No server, no key: Verba runs on your existing Claude Code login, as the scope requires.
- The CLI checks the reply's shape and Core checks its meaning, so a bad lesson never reaches the screen or the database.
- Every failure has a named case and a fix it yourself message, and the Settings section makes the whole thread testable before any lesson screen exists.
- Later calls (grading, placement, chat) reuse the runner, the status cache, the error classification, and the prompt resource pattern; each adds only a prompt, a schema, and a mapper.

**Negative / tradeoffs**:
- Each call starts a fresh CLI process (about 1 s of process and CLI startup measured, plus model time). Fine for lessons; chat may feel it on every turn.
- Verba depends on CLI flags it does not control. `--safe-mode` is documented as a troubleshooting flag and could change; if `-p` ever defaults to bare mode, subscription login breaks. The version minimum and the live tests are the early warning, and the Anthropic API key path (deferred in scope) is the escape hatch.
- Usage limit detection reads `api_error_status` and error text, which the CLI may reword; a missed match degrades to the generic `failed` message, not a crash.
- A retry doubles plan usage and waiting time for a bad reply; worst case a lesson takes about 4 minutes before failing.
- The login shell lookup runs your shell startup files once per check, which can be slow or noisy; it is the last resort, after the saved path and known paths.
- Fair option length is only warned about, so a lopsided quiz can still be shown.
- If swift-subprocess cannot start the child in its own process group, a timeout or cancel signals only `claude` itself; for an npm install that is a Node wrapper, a grandchild could outlive it briefly. The native installer (your setup) has no wrapper.
- Because a `problem` status is never cached, each call made while Claude Code is broken pays about 1 s for a fresh status check.

**Neutral**:
- `ClaudeBridge` gains package resources; prompts become versioned files reviewed like code.
- `generation.promptVersion` values now follow the `<call>-v<N>` pattern.
- The Settings window grows from its placeholder size.

## Follow-up

- [ ] Feature 6 (first lesson loop) must decide how `fillBlank` is graded: Core's `Grader` returns nil for it today, and this spec's lesson schema includes it. Without a decision, Slice 1 cannot grade a `fillBlank` exercise.
- [ ] Add `translate` to the lesson schema as `lesson-v2` once feature 6 decides how translations are graded.
- [ ] Tutor chat (feature 10): build the streaming contract above, confirming the stream-json event names against the installed CLI, and name its Core protocol.
- [ ] Learning goal (feature 7), placement and levels (feature 8), and learner memory (feature 11) each add their context to a new lesson prompt version; recent lesson topics are a cheap addition if lessons start repeating.
- [ ] During `/check verify`, confirm on the built, ad hoc signed app that the child `claude` reads its login without a Keychain prompt (open item from spec 0001).
- [ ] Recheck the pinned flags on each Claude Code update you install (run the live tests); raise the minimum version when a flag changes.
- [ ] Once `ClaudeBridge` has real code, consider a nested `Packages/VerbaKit/Sources/ClaudeBridge/AGENTS.md` (pinned flags, prompt versioning, no `--bare`) so agents working there load it; `/sync` owns that.
