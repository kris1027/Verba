# Scope: Verba

A macOS app that teaches any language with Claude as the teacher. You pick your native language and the language you want to learn, and every lesson, explanation, and correction comes in your native language. Everything runs on your Mac (no server): Claude is reached through the local Claude Code CLI, and your lessons, progress, and learner memory are saved on the machine. Built for personal use first, free.

**Build approach:** Tracer Bullet (each slice runs end to end through screen, Claude, and saved data; later slices thicken one strand of a thread that already works).
**Workflow:** Alpha (after `/develop`, run `/check verify` on the real app). The project default level of rigor. `/architect` is the recommended first stop for a feature with a real decision, but skippable when you already know the build. Any feature can carry its own tag (e.g. `· Beta`) to do more or less.

_These are recommendations to keep your build orderly, not requirements. Skip anything that does not fit: if you already know how to build a feature, use `/develop` and skip `/architect`. You decide when a feature is `done`._

## Teaching principles

Every feature that creates or grades learning material follows these. `/architect` should turn them into concrete rules in the lesson, memory, and review specs.

- **Goal first.** Each language has a learner goal (trip, job, exam, family). Every lesson ties back to it, so lessons never feel abstract.
- **Just hard enough.** The next lesson sits right above what you have shown you know (your level plus your learning records), never re-teaching what you have proven and never jumping far ahead.
- **Explain, then practice.** A lesson first explains one small thing simply (difficulty hurts here), then drills it with effortful recall (difficulty helps here). Short enough to finish in one sitting, with one clear win.
- **Instant feedback.** Every answer gets graded and explained right away, in your native language.
- **Long term memory over the feeling of fluency.** Recall from memory, spaced review over days, and mixing related topics in practice. Knowing it during the lesson is not the goal; knowing it next week is.
- **Proof, not coverage.** Something counts as learned only when you showed it (a correct answer, a correct use in chat), not because a lesson mentioned it.
- **Fair quizzes.** Answer options are similar in length, and the app (not Claude) shuffles their order, so position and formatting never give the answer away.

## At a glance

| # | Feature | Phase | Status |
|---|---------|-------|--------|
| 1 | Stack & architecture | Foundation | done |
| 2 | Coding standards & tooling | Foundation | done |
| 3 | Data model | Foundation | in-progress |
| 4 | Claude Code bridge | Foundation | planned |
| 5 | Design system & UI foundation | Foundation | planned |
| 6 | First lesson loop | Slice 1 | planned |
| 7 | Learning goal | Slice 2 | planned |
| 8 | Placement check & levels | Slice 2 | planned |
| 9 | Progress & lesson history | Slice 2 | planned |
| 10 | Tutor chat | Slice 3 | planned |
| 11 | Learner memory | Slice 4 | planned |
| 12 | Review & what's next | Slice 5 | planned |
| 13 | Reference notebook | Slice 6 | planned |
| 14 | Several languages per learner | Slice 7 | planned |
| 15 | Pronunciation audio | Slice 8 | planned |
| 16 | Speaking practice | Slice 9 | planned |

## Foundations

### 1. Stack & architecture · Beta · done
Decide how the native macOS app is built and where its data lives on disk, then scaffold a runnable app every slice builds on.
**Done when:** the stack is recorded in a spec, and an empty app window builds and launches on the Mac.
spec [0001](../specs/0001-stack-architecture/index.md) · code in `App/`, `Packages/VerbaKit/`, `project.yml`
- [x] Decide the stack (spec): `/architect stack & architecture`
- [x] Scaffold from the decision: `/develop stack & architecture`

### 2. Coding standards & tooling · done
Capture conventions from the real scaffolded project, then install lint, format, and pre-commit checks.
**Done when:** root `AGENTS.md` reflects the real stack, and lint and format run clean.
code in `.swift-format`, `.swiftlint.yml`, `.githooks/pre-commit`
- [x] Capture conventions + tooling choices: `/audit`
- [x] Install the tooling: `/develop tooling`

### 3. Data model · in-progress
The saved shape of everything the app remembers: learner, language pairs, goal, level, lessons, exercises and answers, chat sessions, learning records, teaching preferences, review items, reference notes.
**Done when:** every lesson, answer, chat, and score survives an app restart, and the shape already fits later slices (several languages, records, review, notebook) without a breaking migration.
spec [0002](../specs/0002-data-model/index.md) · code in `Packages/VerbaKit/Sources/Core/`, `Packages/VerbaKit/Sources/Persistence/`, `Packages/VerbaKit/Sources/Features/Launch/`, `App/`
- [x] Design it (spec): `/architect data model`
- [x] Build it: `/develop data model`
  - [x] Core value types, rules (state, score, shuffler, grader), errors, and store protocols (AC-5, AC-6, AC-7, AC-8, AC-9, AC-14)
  - [x] `v1_core` migration with the seven Slice 1 tables, row mapping, and error mapping (AC-1, AC-2, AC-3)
  - [x] `LearnerStore` and `LessonStore` on GRDB with live streams and archive rules (AC-2, AC-3, AC-4, AC-7, AC-8, AC-9, AC-10, AC-13, AC-14)
  - [x] Backup before migrating and the launch error screen instead of a crash (AC-11, AC-12)
- [ ] Verify it: `/check verify data model`

### 4. Claude Code bridge · needs a decision
The one place the app talks to Claude, by running the local Claude Code CLI: sending prompts with the right learner context, getting structured lesson data back, streaming chat replies, and handling failures.
**Done when:** the app can send a prompt and get a usable reply through Claude Code; structured replies are validated before use; a missing install, a logged out session, or a timeout shows a clear message instead of a crash.
- [ ] Design it (spec): `/architect claude code bridge`

### 5. Design system & UI foundation · needs a decision
Calm, readable, book like visual language and base components (lesson page, exercise with instant feedback, quiz with shuffled options, chat bubble, progress view) so every screen feels like one course.
**Done when:** `design.md` covers type, color, spacing, and components, with light and dark mode; base components handle focus and keyboard; lesson pages print cleanly.
- [ ] Design it (spec): `/architect design system & UI foundation`

## Slice 1: First lesson loop

### 6. First lesson loop · needs a decision
The thinnest real thread: choose your native and target language, Claude writes one short lesson in your native language (explain one thing, then practice it), you answer, each answer is graded and explained right away, and the result is saved. This slice is the walking skeleton.
**Done when:** on first launch you pick two languages and finish one generated lesson that explains first and then drills; every answer gets instant feedback in your native language; quiz options are shuffled by the app; after quitting and reopening, the lesson and your score are still there.
- [ ] Design it (spec): `/architect first lesson loop`

## Slice 2: Goal, level, and progress

### 7. Learning goal
Ask why you are learning this language (trip, job, exam, family, fun) and what success looks like, then give that goal to Claude with every lesson. You can change it later.
**Done when:** onboarding asks for the goal and won't accept an empty answer; generated lessons visibly use the goal (topics, vocabulary, examples); you can edit the goal in settings.
- [ ] Build it: `/develop learning goal`

### 8. Placement check & levels · needs a decision
A short placement check sets your level (A1 to C2) and asks what you already know, so the first lessons don't assume too much or re-teach the basics. Each next lesson follows your level, and good results move you up.
**Done when:** a new learner takes the placement check and gets a level; the next lesson matches it; the level rises after enough passed lessons; "too easy" or "too hard" after a lesson adjusts the next one.
- [ ] Design it (spec): `/architect placement check & levels`

### 9. Progress & lesson history · needs a decision
A home screen with your goal, level, finished lessons, and a "continue" button; any past lesson can be reopened with your answers, and lessons link to related earlier lessons.
**Done when:** home shows goal, level, and lesson count; "continue" starts the right next lesson; every past lesson opens with its saved answers and grades.
- [ ] Design it (spec): `/architect progress & lesson history`

## Slice 3: Tutor chat

### 10. Tutor chat · needs a decision
Free practice conversation with Claude as a tutor who answers in your target language, explains in your native language, and corrects your mistakes. You can also open the tutor from any lesson to ask a follow up question about it.
**Done when:** you can chat with the tutor; mistakes get a correction explained in your native language; an "ask about this lesson" button opens a chat that already knows the lesson; each conversation is saved and can be reopened.
- [ ] Design it (spec): `/architect tutor chat`

## Slice 4: Learner memory

### 11. Learner memory · needs a decision
Learning records about you, kept per language and given to Claude so every lesson starts from what you really know. A record is written only on proof: something you showed you can use, prior knowledge you stated, or a mistake that was corrected. Old records are marked replaced, not deleted. Also stores how you like to be taught (for example "more grammar tables", "formal register", "examples about my job").
**Done when:** after a lesson or chat, new records appear only for proven knowledge, stated prior knowledge, or corrected mistakes; the next lesson visibly targets a weak spot and skips what is proven; your teaching preferences shape lessons; you can view and edit your records and preferences.
- [ ] Design it (spec): `/architect learner memory`

## Slice 5: Review

### 12. Review & what's next · needs a decision
Spaced repetition with mixed practice: words, phrases, and corrected mistakes come back when due, mixed across topics. "Continue" decides between a new lesson, a due review, or practice in chat, so the app knows when to stop adding new material.
**Done when:** items from finished lessons appear in a review session when due, mixed across topics; a correct recall pushes the item further out, a wrong one brings it back sooner; home shows reviews due; when many reviews are due, "continue" sends you to review before a new lesson.
- [ ] Design it (spec): `/architect review & what's next`

## Slice 6: Reference notebook

### 13. Reference notebook · needs a decision
The short version of every lesson, kept for quick lookup: grammar cheat sheets, conjugation tables, useful phrases, and your personal vocabulary list. A word joins your vocabulary list only once you have used it correctly. This is what you come back to later; lessons are where you learn it the first time.
**Done when:** each finished lesson adds or updates a cheat sheet page; words enter your vocabulary only after a correct use; lessons link to their notebook pages; any page can be printed or saved as PDF.
- [ ] Design it (spec): `/architect reference notebook`

## Slice 7: Several languages

### 14. Several languages per learner
Learn more than one target language, each with its own goal, level, history, records, reviews, and notebook, and switch between them.
**Done when:** you can add a second target language, switch between them, and each keeps its own goal, level, lessons, records, reviews, and notebook.
- [ ] Build it: `/develop several languages per learner`

## Slice 8: Pronunciation

### 15. Pronunciation audio · needs a decision
The app reads words and sentences aloud in the target language with the voices built into macOS.
**Done when:** words and example sentences in lessons, chat, review, and the notebook have a play button that speaks them in the target language; a language with no installed voice shows a hint instead of failing.
- [ ] Design it (spec): `/architect pronunciation audio`

## Slice 9: Speaking practice

### 16. Speaking practice · needs a decision
Answer out loud: the app turns your speech into text and Claude checks it like a typed answer.
**Done when:** you can speak an answer in an exercise or chat, see the recognized text, and get Claude's feedback; a denied microphone permission shows how to turn it on.
- [ ] Design it (spec): `/architect speaking practice`

## Deferred
Out of scope for the current build pass, kept so the plan stays honest.
- **Trusted sources in lessons**: each lesson points to one checked outside source (dictionary, grammar reference) instead of trusting Claude alone; needs a vetted source list per language so links are never made up · needs a decision
- **Real world practice**: suggest places to use the language with real people (language exchange, local meetups, communities), respecting a "no thanks" · needs a decision
- **App interface in the native language**: menus and buttons translated (lessons are already native from Slice 1)
- **Backup, export, and sync**: move progress to another Mac or iCloud · needs a decision
- **Other ways to reach Claude**: an Anthropic API key in the Keychain as an alternative to Claude Code · needs a decision
- **Public distribution**: signing, notarization, and release for other people · needs a decision
- **Database growth cleanup** (from spec 0002): attempts and raw Claude replies are kept forever; revisit only if the database passes about 100 MB
- **Payments**: only if the app is ever sold · needs a decision · GA

## Legend

**The decision box.** Every feature carries exactly one, the sub-task whose label ends with `(spec)`. Its wording varies (`Design it (spec)` normally, `Decide the stack (spec)` on Stack & architecture), so skills locate it by that `(spec)` suffix, never by an exact label. Every other box is an execution box and `/architect` never ticks one.

**Feature lifecycle**: the scope updates as a feature moves; each row is what it shows and who sets it:

| State | Set by | The feature shows |
|---|---|---|
| `planned` · needs a decision | `/scope` | one box: `Design it (spec): /architect <feature>` |
| `in-progress` (designed) | **`/architect` at spec capture** | `Design it` ticked; spec linked; `Build it: /develop <feature>` + **2 to 5 milestones**; the tier's closing boxes (`Verify it` Alpha+, `Test it` Beta+, `Review it` + `Document it` GA); any surfaced follow-up enrolled |
| `in-progress` (building) | `/develop` | milestone sub-boxes tick one by one; code pointer filled |
| `in-progress` (verified) | `/check verify` | `Build it` + milestones ticked; `Verify it` ticked |
| `done` | **you, when you decide it is** (any skill sets it when you say so); `/sync` reconciles | boxes you ran ticked, skipped ones marked skipped; the tier's last stage (`Prototype` → after `/develop`; `Alpha` → after `/check verify`; `Beta`/`GA` → after `/test`) is the suggested point to call it done; `/sync` captures conventions |

- **Next step** = the first unticked box (always a command or a tracked milestone).
- **needs a decision** = run `/architect` first; otherwise straight to `/develop` (or `/audit` for standards & tooling). The tag drops once the spec is captured.
- **Atomic build tasks live in the spec's `## Build plan`, not here**: the scope carries only the milestone rollup.
- **Status** `planned` → `in-progress` → `done`, plus `existing` (pre-workflow) and `dropped` (de-scoped, kept for history).
- **Approach tag** beside a heading (e.g. `· Facade`) overrides the project default for that feature; no tag = inherits it.
- **Workflow tier tag** beside a heading (e.g. `· GA`, `· Prototype`) sets that one feature's rigor above or below the project default; no tag inherits the default. It decides the feature's check boxes and each skill's next suggestion.
- **Workflow** (header line) is the project default, what runs after `/develop`: **Prototype** = nothing (trust develop's own build time self check); **Alpha** = `/check verify`; **Beta** = `/check verify` then `/test`; **GA** = adds a fresh model `/check review` then `/document`. A feature built on an unratified decision (an `Assumed` spec) stays flagged, but that never blocks `done`.
- **Pointer line** (`spec <n> · code in <path>`): the spec link added by `/architect`, the code path by `/develop`.
