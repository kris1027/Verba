# Verify: Claude Code bridge · spec 0003 · updated 2026-11-17
_These steps come from the acceptance criteria in spec 0003. `/check verify` runs them, and `/test` can lock in the ones that should stay._

## UI / manual
- [x] Open Verba Dev, then Settings (⌘,). Expect the Claude section to show a progress indicator, then `Ready, Claude Code <version>`, and the path in use (`~/.local/bin/claude` on this Mac). → AC-4, AC-12
- [x] Press **Send Test Prompt**. Expect the button to stay disabled while it runs, then `Reply received in <n.n> s from claude-haiku-…`. → AC-13
- [x] Check that the child `claude` reads its login without a Keychain prompt on this ad hoc signed build (open item from spec 0001). → AC-13
- [x] Press **Choose…** and pick a plain text file. Expect the message "The Claude Code path in Settings isn't a program…". Press **Use Automatic** and expect `Ready` again with the automatic path. → AC-1, AC-4, AC-12
- [x] Switch **Model** to Opus, quit and reopen. Expect Opus to still be selected (`defaults read com.verba.app.dev claude.model` prints `opus`). Set it back to Sonnet. → AC-14
- [x] Run `claude auth logout` in Terminal, then press **Check Again**. Expect "Claude Code isn't signed in…". Sign in again in Terminal, then press **Check Again** and expect `Ready`. → AC-3, AC-4
- [x] With VoiceOver on, move through the Claude section. Expect every control to be announced with a label, in reading order (Status, Claude Code path, Choose, Use Automatic, Model, Check Again, Send Test Prompt). Check that text contrast holds in light and dark mode. → AC-12
- [x] In Console.app (subsystem `com.verba.app.dev`, category `bridge`), check that the binary path, prompts, and replies show as `<private>`, while exit status, duration, model, and error case show in plain text. → AC-15

## Commands
- [x] `swift test --package-path Packages/VerbaKit` → all suites pass (live suite skipped) → AC-1 to AC-16
- [x] `VERBA_LIVE_CLAUDE=1 swift test --package-path Packages/VerbaKit --filter LiveClaudeTests` → status ready, test prompt replies, and a haiku lesson validates with `claude-work/` empty → AC-5, AC-6, AC-13
- [x] `ls ~/Library/Application\ Support/Verba-Dev/claude-work` after the manual test prompt → empty → AC-5

## Value sourcing
- [x] Native and target language in the prompt: `PromptTests.lessonPromptNamesBothLanguagesAndTheTopic` (Polish (pl) / Spanish (es)). → AC-6
- [x] Topic line: a hint containing `"` and `{{…}}` stays quoted and literal; no hint gives the beginner sentence. → AC-6
- [x] `--model`: an unknown saved value gives `sonnet`, and `opus` gives `opus` (`IsolationTests.modelPreferenceIsPassedAsModel`). → AC-14
- [x] `NewGeneration.model`: most output tokens wins, ties go alphabetically, and an empty usage gives nil. → AC-6
- [x] `rawReply`: the `result` text, or `structured_output` with sorted keys when the text is empty. → AC-6
- [x] Child `PATH`: the binary folder, then the login shell `PATH` or the Homebrew folders, then the app `PATH`, with duplicates removed. → AC-5
- [x] `durationMs`: positive in the live run, and shown with one decimal in Settings. → AC-6, AC-13
- [x] Version, path, and signed in state: the status tests (`StatusCheckTests`). → AC-2, AC-3

## Acceptance-criteria coverage
- AC-1 `CLILocatorTests`, plus the manual Choose step · AC-2 and AC-3 `StatusCheckTests` · AC-4 `StatusCacheTests`, plus the manual Check Again step
- AC-5 `IsolationTests`, `SubprocessRunnerTests.passesArgumentsStdinCwdAndEnvironment`, and the live run · AC-6 and AC-7 `WriteLessonTests`, `LessonMapperTests`, and the live run
- AC-8 `LessonMapperTests.unusableRepliesAreRejected`, plus the retry tests · AC-9 the runner timeout and cancel tests, plus `cancelAfterABadFirstReplyDoesNotStartTheRetry`
- AC-10 and AC-11 `FailureClassificationTests` · AC-12 `ClaudeSettingsModelTests`, `ClaudeErrorTests`, and the manual UI steps · AC-13 `TestPromptTests`, `testButtonIsDisabledWhileATestRuns`, and the manual step
- AC-14 `ClaudePreferencesTests` and the model argument test · AC-15 the Console step (checked by review) · AC-16 `lopsidedOptionsAreFlaggedButAccepted`
