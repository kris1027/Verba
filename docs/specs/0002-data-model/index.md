# 0002. One relational schema for everything the app remembers, grown slice by slice

**Date**: 2026-11-05
**Status**: In Progress

## Summary

This spec fixes the saved shape of everything Verba remembers: you, each language you learn (a course), lessons, exercises, every answer you give, chats, learning records, reviews, and the notebook. It designs all nineteen tables up front so later slices never need a breaking change, but this feature only creates the seven tables Slice 1 uses; each later slice adds its own tables with a small, additive migration (a numbered schema change). Nothing you learn is ever deleted: things are archived or marked replaced. For building, this means Core value types and store protocols for learners and lessons, one GRDB migration named `v1_core`, a backup before every future migration, and a clear error screen instead of a crash when the database cannot open.

## Requirements

**User stories**:
- As a learner, I want every lesson, answer, and score I produce to still be there after I quit and reopen the app, so that my progress is real.
- As a learner, I want a past lesson to reopen exactly as I saw it (same option order, my answers, my grades), so that I can see what I got wrong.
- As a learner, I want my history kept even when I tidy up, so that proof of what I know is never lost.
- As the builder of later slices, I want the schema designed whole now, so that goals, levels, chat, memory, review, and the notebook arrive as additive migrations.

**Acceptance criteria** (the contract, each criterion is IDed and independently checkable):
- **AC-1**: Opening a database that has only `v0_scaffold` applies `v1_core`, which creates exactly `learner`, `course`, `lesson`, `exercise`, `exercisePart`, `attempt`, and `generation` with the columns, keys, checks, and indexes in *Data model sketch*; foreign keys are enforced (`PRAGMA foreign_keys` is 1) and `v0_scaffold` stays in the migration history.
- **AC-2**: A learner, a course, a lesson with its exercises, parts, saved display order, attempts, and generation, written through the stores, reads back equal (same values, same order) as a `LessonDetail` (which includes its `Generation`) after the database file is closed and opened again. Every `Date` the store writes is rounded to the millisecond before it is stored and returned, so equality holds across the round trip.
- **AC-3**: Saving a generated lesson is all or nothing: if any row of the lesson, its exercises, its parts, or its generation fails to insert, no row of that lesson or its generation exists afterwards and the store throws a `StoreError` (`notFound` when the course does not exist, `unavailable` for any other database error).
- **AC-4**: There is exactly one learner. `loadOrCreateLearner()` creates it on the first call and returns the same learner (same id) on every later call, including after a reopen and when several first calls run at the same time.
- **AC-5**: A learner has at most one course per target language. Adding a second course with the same target language throws `StoreError.duplicateCourse`; each course stores its own native language, which may differ between courses.
- **AC-6**: Languages are BCP 47 tags (standard language codes such as `pl`, `es`, `pt-BR`). `LanguageTag` cannot be built from an empty or malformed string (it throws `ValidationError.invalidLanguageTag`), and a course whose target language equals its native language is rejected with `ValidationError.sameLanguage`.
- **AC-7**: A lesson moves only forward through `ready` → `inProgress` → `completed`. Saving a generated lesson sets `ready`; a `NewLesson` with no exercises is rejected (`ValidationError.emptyLesson`). The first attempt on any exercise sets `inProgress` and `startedAt`; the attempt that leaves no exercise without an attempt sets `completed` and `completedAt` (for a one exercise lesson both happen on its first attempt). Both timestamps equal that attempt's `answeredAt`. Attempts after completion are saved without changing the state or the timestamps.
- **AC-8**: Every attempt is kept. Attempts are numbered from 1 per exercise in the order saved; the lesson score is the number of exercises whose attempt 1 is graded `correct`, out of the exercise count; `partlyCorrect` and unanswered exercises count as not correct; a later correct attempt never changes the score.
- **AC-9**: Quiz option order is shuffled once by the app and saved: the first call to save an exercise's display order stores a position for each displayed part, all in one write; reading the exercise again (also after a reopen) returns that same order; a second save for the same exercise throws `StoreError.displayOrderAlreadySet` and leaves the stored order unchanged. An order that is not exactly the exercise's displayed parts (missing, extra, duplicate, or unknown ids, or any order for a `fillBlank` or `translate` exercise) is rejected with `ValidationError.invalidDisplayOrder`.
- **AC-10**: Nothing is hard deleted. The store protocols offer archive and unarchive, never delete. An archived lesson or course is left out of list reads but still reads by id with its exercises and attempts; archiving an archived row does nothing. An archived course takes no new lessons and an archived lesson takes no new attempts (`StoreError.archived`). Adding a course for a language whose course is archived throws `duplicateCourse`, and `unarchiveCourse` brings it back. A raw SQL `DELETE` of a lesson that has exercises fails on the foreign key.
- **AC-11**: When an existing database file has pending migrations, the app first writes a backup copy to `backups/verba-<UTC timestamp>.sqlite` in the data folder and keeps only the newest 3 backups (pruning deletes only files named `verba-*.sqlite` in that folder, the one place the app deletes anything). A brand new file, or a file with nothing pending, produces no backup. If the backup fails, no migration runs and the launch fails as in AC-12.
- **AC-12**: If the database cannot be opened, backed up, or migrated, the app shows an error screen with a plain message in English, a **Show Database in Finder** button, and a **Quit** button, instead of crashing. No learning data is lost: on an open failure the main database file's bytes are unchanged (SQLite may add its own `-wal` and `-shm` side files), and a failed migration rolls back so the file keeps its last good migration. A failure in `prepareFolders()` shows the same screen.
- **AC-13**: Lesson reads are live: an open lesson list and an open lesson detail receive the current value first, then an updated value through their `AsyncStream` after an attempt, a display order, or an archive is saved, with no manual refresh.
- **AC-14**: The app grades what it can by itself. A Core `Grader` returns `correct` or `wrong` for `choice`, `reorder`, and `match` responses using the rules in *How each exercise kind uses its parts*. `recordAttempt` rejects a response whose shape does not fit the exercise kind, or whose part ids do not belong to that exercise (`ValidationError.invalidResponse`).

## Decision

**Chosen option**: Option 2: one designed target schema, created slice by slice with additive migrations.

Store everything in normalized relational tables (with real columns for what the app grades, shuffles, lists, and schedules, and text or JSON columns only for content the app shows but never queries), designed whole now, with this feature creating the Slice 1 tables in `v1_core` and each later slice appending its own additive migration.

**Implementation skills**: `grdb` (`johnrogers/claude-swift-engineering`, `.agents/skills/grdb/`) · `swift-concurrency` (`avdlee/swift-concurrency-agent-skill`, `.agents/skills/swift-concurrency/`) · `swift-testing-pro` (`twostraws/swift-testing-agent-skill`, `.agents/skills/swift-testing-pro/`)

## Rationale

Reasoning and options: see [rationale.md](rationale.md).

## Feature design

### Conventions every table follows

- **Names**: singular camelCase table names and camelCase column names (`exercisePart.displayPosition`), matching GRDB's `Codable` record mapping so no coding keys are needed. Runner up: snake_case, rejected because every record would need a `CodingKeys` table.
- **Keys**: every primary key is `id TEXT NOT NULL PRIMARY KEY` holding a lowercase UUID (36 characters, `CHECK (length(id) = 36 AND id = lower(id))`). Link tables use a composite primary key instead. Core builds the id before saving, so a lesson parsed from Claude's reply already has its identity. Row structs store ids as `String` (`uuid.uuidString.lowercased()`) and convert in the mapping layer; `UUID` and `ID<Entity>` are never used as GRDB column types (GRDB would store a `UUID` as a 16 byte blob).
- **Times**: `DATETIME` columns in UTC, GRDB's default text encoding (`yyyy-MM-dd HH:mm:ss.SSS`, which sorts correctly as text). All `createdAt` and `answeredAt` values are set by the store, never by the caller, from one `now` rounded to the millisecond per write.
- **Foreign keys**: always on (GRDB's default), declared `ON DELETE RESTRICT`, and every foreign key column is indexed (directly or as the first column of a unique index).
- **No hard deletes**: rows that can be hidden carry `archivedAt DATETIME` (nullable); rows that can be superseded carry `replacedById` (later slices). No `DELETE` statement exists in `Persistence`.
- **Closed sets** (values the app's logic depends on) get a `CHECK`: `lesson.state`, `attempt.grade`, `attempt.gradedBy`, and every boolean column (`IN (0,1)`). **Open sets** (kinds that grow without a migration) are plain `TEXT` without a check: `lesson.kind`, `exercise.kind`, `generation.kind`. Core decodes an unknown open set value as an error, never a crash.
- **JSON columns** are `TEXT` holding JSON written by GRDB's `Codable` encoding, used only for values the app never filters by (`attempt.response`, later `reviewItem.schedulerState`).
- **Errors**: every GRDB call goes through one internal `mapError` helper that turns a foreign key failure on a parent id into `StoreError.notFound`, a unique failure on `course (learnerId, targetLanguage)` into `duplicateCourse`, and anything else into `unavailable(reason:)`. Do not rely on typed throws inference across `writer.write`; catch and map outside the closure. Every error case has its own `errorDescription`.
- **Mapping**: `Persistence` defines internal GRDB record structs (`LessonRow`, `AttemptRow`, …) and maps them to and from the public Core value types. Core types never conform to GRDB protocols. Runner up: retroactive GRDB conformances on Core types, rejected because they leak GRDB into the Core type's public surface and need `@retroactive`.

**Data model sketch**:

Created by this feature in migration `v1_core` (Slice 1):

| Table | Column | Type | Null | Notes |
|---|---|---|---|---|
| `learner` | `id` | TEXT | no | PK. Exactly one row (enforced by the store). |
| | `displayName` | TEXT | yes | Optional; Claude may address you by it. |
| | `createdAt` | DATETIME | no | |
| `course` | `id` | TEXT | no | PK. One per target language you learn. |
| | `learnerId` | TEXT | no | FK `learner.id`. |
| | `targetLanguage` | TEXT | no | BCP 47 tag, canonical form from `LanguageTag`. |
| | `nativeLanguage` | TEXT | no | BCP 47 tag; per course. `CHECK (targetLanguage <> nativeLanguage)`. |
| | `createdAt` | DATETIME | no | |
| | `archivedAt` | DATETIME | yes | |
| | | | | `UNIQUE (learnerId, targetLanguage)` |
| `generation` | `id` | TEXT | no | PK. One row per Claude call whose reply is kept. |
| | `courseId` | TEXT | no | FK `course.id`, indexed. |
| | `kind` | TEXT | no | Open set; Slice 1 writes `lesson`. Later: `grade`, `chatTurn`, `placement`. |
| | `model` | TEXT | yes | Model name the CLI reported, if any. |
| | `promptVersion` | TEXT | no | Set by ClaudeBridge (feature 4 spec). |
| | `rawReply` | TEXT | no | Claude's reply exactly as received. Learner content: logged only as private. |
| | `durationMs` | INTEGER | no | `CHECK (durationMs >= 0)` |
| | `createdAt` | DATETIME | no | |
| `lesson` | `id` | TEXT | no | PK. |
| | `courseId` | TEXT | no | FK `course.id`. Index `(courseId, createdAt)`. |
| | `generationId` | TEXT | yes | FK `generation.id`, indexed. Null only for lessons not written by Claude. |
| | `kind` | TEXT | no | Open set: `regular` now, `placement` in Slice 2. |
| | `title` | TEXT | no | |
| | `topic` | TEXT | no | Short label (for example "Past tense"); later the notebook page key. |
| | `explanation` | TEXT | no | The explain part, as Markdown in your native language. |
| | `state` | TEXT | no | `CHECK (state IN ('ready','inProgress','completed'))`. Table checks: `CHECK ((state = 'ready') = (startedAt IS NULL))` and `CHECK ((state = 'completed') = (completedAt IS NOT NULL))` |
| | `createdAt` | DATETIME | no | |
| | `startedAt` | DATETIME | yes | Set on the first attempt. |
| | `completedAt` | DATETIME | yes | Set when the last unanswered exercise gets an attempt. |
| | `archivedAt` | DATETIME | yes | |
| `exercise` | `id` | TEXT | no | PK. |
| | `lessonId` | TEXT | no | FK `lesson.id`. |
| | `position` | INTEGER | no | Order in the lesson, from 0. `UNIQUE (lessonId, position)` |
| | `kind` | TEXT | no | Open set: `choice`, `fillBlank`, `translate`, `reorder`, `match`. |
| | `prompt` | TEXT | no | What the learner sees. |
| | `explanation` | TEXT | yes | Why the answer is right, shown after answering. |
| `exercisePart` | `id` | TEXT | no | PK. |
| | `exerciseId` | TEXT | no | FK `exercise.id`, indexed. |
| | `sourcePosition` | INTEGER | no | Order Claude wrote it in, from 0. `UNIQUE (exerciseId, sourcePosition)`. Never used as display order. |
| | `text` | TEXT | no | |
| | `displayPosition` | INTEGER | yes | The app's saved shuffle, from 0. Null until shown; null forever for parts never displayed (accepted answers). Partial unique index `(exerciseId, displayPosition) WHERE displayPosition IS NOT NULL`, so a saved order is always a real permutation. |
| | `isCorrect` | INTEGER | yes | Bool, `CHECK (isCorrect IN (0,1))`. `choice`: the right option(s). `fillBlank`, `translate`: an accepted or reference answer. |
| | `correctPosition` | INTEGER | yes | `reorder`: where this token belongs, from 0. |
| | `matchKey` | TEXT | yes | `match`: two parts with the same key form a pair. |
| `attempt` | `id` | TEXT | no | PK. |
| | `exerciseId` | TEXT | no | FK `exercise.id`. |
| | `attemptNumber` | INTEGER | no | From 1, assigned by the store. `UNIQUE (exerciseId, attemptNumber)`, `CHECK (attemptNumber >= 1)` |
| | `response` | TEXT | no | JSON of `AttemptResponse` (see Core types). |
| | `grade` | TEXT | no | `CHECK (grade IN ('correct','partlyCorrect','wrong'))` |
| | `feedback` | TEXT | no | Explanation in your native language. |
| | `gradedBy` | TEXT | no | `CHECK (gradedBy IN ('app','claude'))` |
| | `answeredAt` | DATETIME | no | |

How each exercise kind uses its parts (a Core rule, validated when a lesson is saved; the "Displayed parts" column is `ExerciseKind.displaysParts`, shared by `OptionShuffler` and `saveDisplayOrder`; the "Correct when" column is `Grader`):

| Kind | Parts | Displayed parts | Correct when |
|---|---|---|---|
| `choice` | 2 to 6 options, at least one `isCorrect = 1` | all, shuffled | the chosen part has `isCorrect = 1` |
| `fillBlank` | 1 or more accepted answers, all `isCorrect = 1` | none | not graded by `Grader`; feature 6 spec decides |
| `translate` | 1 or more reference answers, `isCorrect = 1` | none | not graded by `Grader`; feature 6 spec decides (Claude) |
| `reorder` | 2 or more tokens, each with a distinct `correctPosition` | all, shuffled | the response order equals `correctPosition` order |
| `match` | an even number, each `matchKey` used exactly twice | all, shuffled | every response pair shares a `matchKey` |

Target design for later slices (recorded now so their migrations are additive; each slice's own spec may refine column details but not break this shape):

| Slice | Migration adds | Shape |
|---|---|---|
| 2 | columns on `course`: `goalKind` (trip, job, exam, family, fun), `goalText`, `level` (A1 to C2); on `lesson`: `levelSnapshot`, `goalSnapshot`, `difficultyFeedback` (tooEasy, right, tooHard) | all nullable, so `ALTER TABLE ADD COLUMN` suffices |
| 2 | `levelChange` | id, courseId FK, fromLevel?, toLevel, reason (placement, progress, feedback), lessonId? FK, changedAt |
| 2 | `lessonLink` | fromLessonId FK, toLessonId FK, kind (buildsOn, revisits); PK (fromLessonId, toLessonId) |
| 2 | placement check | no table: a `lesson` with `kind = 'placement'`; its result writes a `levelChange` with reason `placement` |
| 3 | `chatSession` | id, courseId FK, lessonId? FK (ask about this lesson), title?, startedAt, archivedAt? |
| 3 | `chatMessage` | id, sessionId FK, sequence (from 1), role (learner, tutor), text, generationId? FK, createdAt; UNIQUE (sessionId, sequence) |
| 3 | `correction` | id, messageId FK, original, corrected, explanation, createdAt |
| 4 | `learningRecord` | id, courseId FK, kind (proven, stated, corrected), subject, detail, attemptId? FK, chatMessageId? FK, correctionId? FK, replacedById? FK self, createdAt; CHECK: `proven` and `corrected` carry exactly one of the three links, `stated` carries none |
| 4 | `teachingPreference` | id, learnerId FK, courseId? FK (null means every language), text, createdAt, archivedAt? |
| 5 | `reviewItem` | id, courseId FK, kind (word, phrase, mistake), front, back, topic, sourceExerciseId? FK, sourceCorrectionId? FK, sourceRecordId? FK, dueAt (indexed with courseId), schedulerState (JSON owned by feature 12 spec's scheduler), createdAt, archivedAt? |
| 5 | `reviewLog` | id, reviewItemId FK, rating, attemptId? FK, reviewedAt |
| 6 | `notebookPage` | id, courseId FK, kind (cheatSheet, table, phrases), topic, title, body (Markdown), createdAt, updatedAt; UNIQUE (courseId, kind, topic) |
| 6 | `notebookPageLesson` | pageId FK, lessonId FK; PK (pageId, lessonId) |
| 6 | `vocabularyEntry` | id, courseId FK, term, normalizedTerm, translation, note?, proofRecordId FK `learningRecord.id`, createdAt; UNIQUE (courseId, normalizedTerm) |
| 7 | none | several languages already fit: one `course` per target language |
| 8, 9 | none expected | voices and speech recognition pick by `course.targetLanguage` |

Relationships: learner 1:N course · course 1:N lesson · course 1:N generation · generation 1:N lesson (normally 1:1) · lesson 1:N exercise · exercise 1:N exercisePart · exercise 1:N attempt.

### Core types (public, in `Core`, each with a `///` doc comment)

- `ID<Entity>`: a generic, `Sendable`, `Hashable`, `Codable` wrapper around `UUID` (phantom type, so a `LessonID` can never be passed where an `ExerciseID` is expected). Type aliases: `LearnerID`, `CourseID`, `LessonID`, `ExerciseID`, `ExercisePartID`, `AttemptID`, `GenerationID`. Runner up: one hand written struct per entity, rejected as boilerplate.
- `LanguageTag`: validated BCP 47 tag. `init(_:) throws(ValidationError)` canonicalizes through `Locale.Language(identifier:)` and rejects empty strings, strings with characters outside letters, digits, and `-`, and identifiers whose language code is missing.
- `Learner`, `Course`, `Lesson`, `Exercise`, `ExercisePart`, `Attempt`, `Generation`: value structs mirroring the columns.
- `ExerciseKind`: enum `choice`, `fillBlank`, `translate`, `reorder`, `match` (decoding an unknown raw value throws), with `var displaysParts: Bool` (true for `choice`, `reorder`, `match`).
- `NewLesson`: what ClaudeBridge (or a test) hands the store: lesson fields plus `[NewExercise]` each with `[NewExercisePart]`. Its public `init` throws `ValidationError.emptyLesson` for no exercises and `ValidationError.invalidExercise(position:reason:)` when a part rule in the table above fails. An `internal` unchecked initializer exists for tests only (`@testable import Core`), so AC-3 can inject a duplicate part id that only the database rejects.
- `LessonState`: enum `ready`, `inProgress`, `completed` with a pure `func advanced(exerciseCount: Int, answeredCount: Int) -> LessonState` (answeredCount = exercises with at least one attempt after this one is saved): `completed` when `answeredCount == exerciseCount`, else `inProgress` when `answeredCount > 0`, else the current state; it never returns an earlier state. The one place AC-7's rule lives.
- `Grader`: pure `static func grade(_ response: AttemptResponse, kind: ExerciseKind, parts: [ExercisePart]) -> Grade?`, returning `correct` or `wrong` for `choice`, `reorder`, `match`, and `nil` for `fillBlank` and `translate` (graded outside the app's own rules, per feature 6 spec). Also `static func validate(_ response:, kind:, parts:) throws(ValidationError)`: `.text` only for `fillBlank`/`translate`, `.choice` for `choice`, `.order` (every displayed part exactly once) for `reorder`, `.pairs` (every part in exactly one pair of two) for `match`, and every part id belongs to the exercise.
- `AttemptResponse`: `Codable` enum `text(String)`, `choice(ExercisePartID)`, `order([ExercisePartID])`, `pairs([[ExercisePartID]])`.
- `Grade` (`correct`, `partlyCorrect`, `wrong`) and `GradedBy` (`app`, `claude`).
- `LessonScore`: `firstTryCorrect` and `exerciseCount`, built by one pure `init(exercises: [(ExerciseID, [Attempt])])`: `exerciseCount` is the number of exercises; `firstTryCorrect` counts exercises whose attempt with `attemptNumber == 1` has grade `correct` (AC-8). Computed in Swift at read time for both `lesson` and `observeLessons` (no SQL version), never stored.
- `OptionShuffler`: `func displayOrder(for kind: ExerciseKind, parts: [ExercisePart], using: inout some RandomNumberGenerator) -> [ExercisePartID]`, the app's shuffle rule (fair quizzes principle); returns `[]` when `kind.displaysParts` is false. Tests pass a seeded generator.
- `LessonDetail`: lesson (all columns, including `archivedAt`), its `Generation` (nil only when `generationId` is null), ordered exercises by `position`, each with its parts (by `displayPosition` once set, else by `sourcePosition`; the set once, whole exercise write means a mix never exists) and its attempts (by `attemptNumber`), plus its `LessonScore`.
- `LessonSummary`: id, title, topic, state, createdAt, completedAt, `LessonScore`.
- Errors: `ValidationError` (`invalidLanguageTag`, `sameLanguage`, `emptyLesson`, `invalidExercise(position:reason:)`, `invalidDisplayOrder`, `invalidResponse`) and `StoreError` (`duplicateCourse`, `notFound`, `archived`, `displayOrderAlreadySet`, `invalid(ValidationError)`, `unavailable(reason:)`), both `LocalizedError` with a user facing message. Store methods use typed throws `throws(StoreError)`; a `ValidationError` raised inside a store call is wrapped as `StoreError.invalid(ValidationError)`.

**State transitions**:

`lesson.state`: `ready` (saved from Claude's reply) → `inProgress` (first attempt on any exercise) → `completed` (every exercise has at least one attempt). No transition goes backwards (`LessonState.advanced` cannot return an earlier state, and the table checks reject inconsistent timestamps). A one exercise lesson goes from `ready` to `completed` on its first attempt. Archiving is the separate `archivedAt` and works in every state; an archived lesson takes no attempts.

**API surface** (Core store protocols, `Sendable`, all methods `async`; implemented by `AppDatabase` in `Persistence`):

| Function | Kind | Key inputs | Key outputs | Access | Key errors |
|---|---|---|---|---|---|
| `LearnerStore.loadOrCreateLearner()` | write, one transaction (select then insert inside one `writer.write`) | none | `Learner` | local app only | `unavailable` |
| `LearnerStore.setDisplayName(_:)` | write | `String?` (trimmed; empty becomes nil) | `Learner` | local | `notFound` |
| `LearnerStore.addCourse(target:native:)` | write | `LanguageTag`, `LanguageTag` (uses the single learner, creating it first if missing) | `Course` | local | `duplicateCourse` (also when that course is archived), `invalid(.sameLanguage)` |
| `LearnerStore.courses(includeArchived:)` | read | `Bool` (default false) | `[Course]` by `createdAt` | local | `unavailable` |
| `LearnerStore.observeCourses()` | live read | none | `AsyncStream<[Course]>`, unarchived | local | stream finishes on error (logged) |
| `LearnerStore.archiveCourse(_:)` | write, no op if already archived | `CourseID` | none | local | `notFound` |
| `LearnerStore.unarchiveCourse(_:)` | write, no op if not archived | `CourseID` | `Course` | local | `notFound` |
| `LessonStore.saveGeneratedLesson(_:generation:)` | write, one transaction | `NewLesson`, `NewGeneration` (kind, model?, promptVersion, rawReply, durationMs) | `LessonDetail` | local | `notFound` (course), `archived` (course), `invalid(.emptyLesson / .invalidExercise)` |
| `LessonStore.lesson(_:)` | read | `LessonID` | `LessonDetail` (archived too) | local | `notFound` |
| `LessonStore.observeLesson(_:)` | live read | `LessonID` | `AsyncStream<LessonDetail>` | local | stream finishes at once if the id is missing, or on error |
| `LessonStore.observeLessons(course:)` | live read | `CourseID` | `AsyncStream<[LessonSummary]>`, unarchived, newest first | local | stream finishes on error |
| `LessonStore.saveDisplayOrder(_:for:)` | write | `[ExercisePartID]` (from `OptionShuffler`), `ExerciseID` | none | local | `displayOrderAlreadySet` (stored order kept; the feature model treats it as fine), `invalid(.invalidDisplayOrder)`, `notFound` |
| `LessonStore.recordAttempt(_:)` | write, one transaction | `NewAttempt` (exerciseID, response, grade, feedback, gradedBy) | `Attempt` (with `attemptNumber`) | local | `notFound`, `archived` (lesson), `invalid(.invalidResponse)` |
| `LessonStore.archiveLesson(_:)` | write, no op if already archived | `LessonID` | none | local | `notFound` |

Every live read is built in `Persistence` from GRDB `ValueObservation` iterated with `values(in:)` inside a `Task`, mapped to Core values, and yielded into an `AsyncStream` created with `bufferingPolicy: .bufferingNewest(1)`; `onTermination` cancels the task. Streams emit the current value first. On a database error the stream logs through `Log.store` and finishes (the screen keeps its last value; accepted tradeoff of the `AsyncStream` rule). GRDB may merge quick writes into one emission, so tests assert that the latest value eventually arrives, never a count of emissions. Never bridge with `start(onChange:)` plus a stored continuation. Archiving a course does not change `observeLessons(course:)` output; callers stop observing an archived course. Writes serialize through the single `DatabasePool` writer, so `recordAttempt` reads the current max `attemptNumber` and inserts inside one write transaction (no duplicate numbers under concurrent calls).

`AppDatabase.open(at:backupsFolder:)` gains the backup step and throws `PersistenceError` (public, with a user facing message; `AppEnvironment` maps it to the error screen). Migration moves out of `AppDatabase.init` into an explicit step, so `init` and `inMemory()` change. The order:
1. Record whether the file exists, before `DatabasePool(path:)` creates it.
2. Open the pool (a corrupt file throws here: `PersistenceError.openFailed`).
3. If the file existed and `migrator.hasCompletedMigrations(db)` is false, open a `DatabaseQueue` at `backups/verba-<yyyy-MM-dd'T'HH-mm-ss'Z'>.sqlite` (add `-2`, `-3` if that name exists) and run `pool.backup(to: queue)`. On failure delete that partial file and throw `PersistenceError.backupFailed`; no migration runs.
4. Prune: list `verba-*.sqlite` in `backups/`, sort by name descending, delete all but the first 3.
5. Migrate (each migration is its own transaction; failure throws `PersistenceError.migrationFailed` and leaves earlier migrations applied).

`AppEnvironment.launch()` returns `LaunchResult` (`ready(AppEnvironment)` or `failed(message:databaseURL:)`), covering `prepareFolders()` too. `VerbaApp` switches on it: `ready` shows `RootView`, `failed` shows `LaunchErrorView`. **Show Database in Finder** calls `NSWorkspace.activateFileViewerSelecting` on the file, or on the data folder when the file does not exist; **Quit** calls `NSApplication.shared.terminate`. `NSWorkspace` stays in the app target (passed into the view as closures), so `Features` keeps only SwiftUI.

**Value sourcing**:

| Action | Value produced / displayed | Source |
|---|---|---|
| `loadOrCreateLearner` | learner id, createdAt | generated by the store (new `UUID`, current time) |
| `addCourse` | target and native language | input `LanguageTag`s, picked during Slice 1 onboarding (feature 6 spec) |
| `saveGeneratedLesson` | lesson, exercise, and part ids | generated in Core when building `NewLesson` |
| `saveGeneratedLesson` | title, topic, explanation, prompts, part texts and roles | Claude's parsed reply (ClaudeBridge, feature 4 spec), carried in `NewLesson` |
| `saveGeneratedLesson` | `promptVersion`, `model`, `rawReply`, `durationMs` | ClaudeBridge (feature 4 spec), carried in `NewGeneration` |
| `saveGeneratedLesson` | `state = ready`, `createdAt` | set by the store |
| `saveDisplayOrder` | each part's `displayPosition` | `OptionShuffler` in Core, called by the feature model the first time an exercise is shown (feature 6 spec owns when) |
| `recordAttempt` | `attemptNumber` | max existing number for that exercise + 1, inside the write transaction |
| `recordAttempt` | `grade`, `feedback`, `gradedBy` | input: for `choice`, `reorder`, `match` the grade comes from `Grader`; for `fillBlank` and `translate`, feature 6 spec decides; feedback and gradedBy per feature 6 spec |
| `recordAttempt` | `answeredAt`, lesson `startedAt`, `completedAt`, new `state` | `answeredAt` = now rounded to the millisecond; `startedAt` and `completedAt` copy `answeredAt` when the state changes; state from `LessonState.advanced` with exercise count and count of exercises with at least one attempt (this one included) |
| `observeLessons`, `lesson` | `LessonScore` | derived in Swift by `LessonScore.init(exercises:)`: exercises whose attempt 1 has `grade = correct`, over exercise count |
| `lesson` | `Generation` | `generation` row by `lesson.generationId` |
| `lesson` (reopen) | option order | `exercisePart.displayPosition`, falling back to `sourcePosition` when unset |
| backup | file name timestamp | current UTC time, format `yyyy-MM-dd'T'HH-mm-ss'Z'` (no colons, safe in Finder, sorts by name), `-2` style suffix on a clash |
| error screen | message, database location | `PersistenceError.errorDescription` (or the `prepareFolders` error's description); `AppPaths.database`, falling back to `AppPaths.root` when the file is missing |

**Key invariants**:
- One learner row; at most one course (archived or not) per (learner, target language); target differs from native (DB `CHECK` plus Core validation).
- Exercise positions per lesson and part source positions per exercise are unique and start at 0; attempt numbers per exercise are unique and start at 1.
- Display positions, once set for an exercise, are never changed, and form a permutation from 0 of exactly its displayed parts (partial unique index plus `saveDisplayOrder` validation).
- Archived courses take no lessons; archived lessons take no attempts.
- A lesson's state never moves backwards; `completedAt` is set if and only if `state = 'completed'`; `startedAt` is set if and only if state is not `ready` (both enforced by table `CHECK`s in `v1_core`, because they cannot be added later without a rebuild).
- Every part satisfies its exercise kind's rules (Core, checked in `NewLesson.init`).
- No row is ever deleted by the app; `ON DELETE RESTRICT` makes an accidental delete fail loudly.
- Applied migrations are never edited; each later slice appends a new named migration (`v2_goalLevel`, `v3_chat`, …) that only adds tables, nullable columns, or indexes. A table rebuild of a Slice 1 table needs its own spec.

**Security model**:
Single local user; no accounts, no network, no server. The database lives in the data folder chosen by `AppEnvironment` (spec 0001), readable by your macOS user only (default Application Support permissions), and backed up by Time Machine. Lesson text, answers, and Claude's raw replies are personal learning content: never logged except with `privacy: .private`. No secrets are stored. Only `Persistence` touches the file; `Features` sees Core types only (enforced by the SwiftLint boundary rules).

**Configuration required**:
None. New paths only: `AppPaths.backups` (`<data folder>/backups/`), created by `prepareFolders()`.

**Critical test scenarios** (each maps to an acceptance criterion in ## Requirements):
- Happy path: on a temp folder `DatabasePool`, create learner and course, save a five exercise lesson (one of each kind), save display orders, record attempts, close, reopen, and read an equal `LessonDetail` with the right score, verifies **AC-1**, **AC-2**, **AC-8**, **AC-9**
- Migration: a file with only `v0_scaffold` migrates to `v1_core`, the schema matches (tables, `PRAGMA foreign_key_list`, indexes), and a backup file appears; a fresh file makes no backup; a fourth backup prunes the oldest, verifies **AC-1**, **AC-11**
- Failure case: a `NewLesson` built with the internal unchecked initializer whose last part reuses an earlier part's id fails on the primary key and leaves zero `lesson`, `exercise`, `exercisePart`, and `generation` rows; a lesson for a random `CourseID` throws `notFound`, verifies **AC-3**
- Failure case: a corrupt file (random bytes) makes `open` throw `openFailed` and the main file's bytes are unchanged afterwards (side files ignored); `AppEnvironment` returns `failed`, verifies **AC-12**
- Concurrency: ten concurrent `loadOrCreateLearner` calls on a fresh database return one id and leave one row, verifies **AC-4**
- Display order: wrong set, duplicate, unknown id, and an order for a `translate` exercise are each rejected; a second save throws `displayOrderAlreadySet` and the order is unchanged, verifies **AC-9**
- Archive: archiving twice is a no op; saving a lesson into an archived course and attempting an archived lesson throw `archived`; `addCourse` for an archived language throws `duplicateCourse` and `unarchiveCourse` restores it, verifies **AC-10**
- Grading: `Grader` parameterized over correct and wrong responses for `choice`, `reorder`, `match`; `validate` rejects a `.text` response to `choice` and a part id from another exercise, verifies **AC-14**
- Concurrency: twenty concurrent `recordAttempt` calls on one exercise produce numbers 1 through 20 with no gaps or duplicates, verifies **AC-8**
- Rules: `LessonState.advanced` parameterized over every (state, counts) pair; `LanguageTag` over valid and invalid strings; `NewLesson` part rules per kind; `OptionShuffler` with a seeded generator returns a permutation of exactly the displayed parts, the same one for the same seed, and across 1,000 seeds puts every option in every position at least once, verifies **AC-6**, **AC-7**, **AC-9**
- Archive: an archived lesson disappears from `observeLessons` but `lesson(_:)` still returns it; raw `DELETE FROM lesson` fails, verifies **AC-10**
- Live reads: `observeLesson` yields a new value after `recordAttempt`, verifies **AC-13**
- Access: not applicable (single local user, no roles); the boundary is checked by SwiftLint's no `GRDB` import in `Features` rule, verifies **AC-2** indirectly

## Build plan

Tracer Bullet: the thread here runs from app launch through `AppEnvironment`, the migrated file, and the stores, back to a Core value a feature model can show. Slice 1's lesson screen then drives this thread for real. The migration is sized to Slice 1 only; later slices add theirs.

1. Core value types: `ID<Entity>` and aliases, `LanguageTag`, `Learner`, `Course`, `Lesson`, `Exercise`, `ExercisePart`, `Attempt`, `Generation`, `ExerciseKind` (with `displaysParts`), `NewLesson` (with the per kind part rules, `emptyLesson`, and the internal unchecked test initializer), `AttemptResponse`, `Grade`, `GradedBy`, with `CoreTests`, satisfies **AC-5**, **AC-6**, **AC-7**
2. Core rules: `LessonState.advanced`, `LessonScore`, `OptionShuffler`, `Grader` (grade and validate), `LessonDetail`, `LessonSummary`, with parameterized `CoreTests`, satisfies **AC-7**, **AC-8**, **AC-9**, **AC-14**
3. Core contracts: `ValidationError`, `StoreError` (each case with its own `errorDescription`), `LearnerStore`, `LessonStore` protocols (archive and unarchive, no delete), plus in memory fakes for `FeaturesTests`, satisfies **AC-4**, **AC-10**
4. `Persistence` migration `v1_core` after `v0_scaffold`: the seven tables with every column, `CHECK`, unique index (including the partial one on `displayPosition`), table check, and foreign key index above; schema test against a temp folder `DatabasePool`, satisfies **AC-1**
5. `Persistence` records and mapping (`LearnerRow`, `CourseRow`, `LessonRow`, `ExerciseRow`, `ExercisePartRow`, `AttemptRow`, `GenerationRow`) with `String` ids and millisecond rounded dates, plus the `mapError` helper, internal only, satisfies **AC-2**, **AC-3**
6. `AppDatabase` implements `LearnerStore` (`loadOrCreateLearner`, `setDisplayName`, `addCourse`, `courses`, `observeCourses`, `archiveCourse`, `unarchiveCourse`) with the concurrent first call test, satisfies **AC-4**, **AC-5**, **AC-10**, **AC-13**
7. `AppDatabase` implements `LessonStore` (`saveGeneratedLesson` in one transaction, `lesson`, `observeLesson`, `observeLessons`, `saveDisplayOrder`, `recordAttempt` with response validation, numbering, and state advance, `archiveLesson`), with the restart, rollback, concurrency, archive, and live read tests, satisfies **AC-2**, **AC-3**, **AC-7**, **AC-8**, **AC-9**, **AC-10**, **AC-13**, **AC-14**
8. Backup before migrating: split migration out of `AppDatabase.init`, `AppPaths.backups`, the five step open order above (existence check, open, backup into a `DatabaseQueue`, prune by name, migrate), fail closed, with tests, satisfies **AC-11**, **AC-12**
9. Launch wiring: `AppEnvironment.launch()` returns `LaunchResult` (ready, with `LearnerStore` and `LessonStore` exposed for feature models, or failed); `VerbaApp` switches on it; replace the `fatalError` with a `LaunchErrorView` in `Features` (message, **Show Database in Finder**, **Quit** as closures from the app target, labelled for VoiceOver, Dynamic Type), satisfies **AC-12**

## Consequences

**Positive**:
- Grading, shuffling, scoring, review scheduling, and the notebook all query real columns; no JSON parsing in hot paths.
- Every later slice has a known, additive place to land; Slice 7 (several languages) needs no migration at all.
- Proof is traceable: every attempt and the raw Claude reply behind every lesson are kept, which learner memory (Slice 4) builds on.
- Restart survival and the rollback rule are proven by tests against a real WAL file, not just in memory.

**Negative / tradeoffs**:
- More code than a JSON blob: seven record structs, mapping, and part rules per exercise kind before the first lesson shows.
- Keeping everything (attempts, raw replies) grows the file forever; at a few KB per lesson this is megabytes over years, but there is no cleanup path yet.
- UUID text keys are larger and slower to join than integers; irrelevant at personal scale, measurable only past millions of rows.
- `CHECK` constraints on closed sets mean adding a new lesson state or grade needs a SQLite table rebuild migration (and a spec).
- The backup fails closed: a full disk blocks launch until space is freed, by design.
- The later slice tables are a target, not built; each slice's spec can still get a column wrong, which is caught at that slice, not now.

**Neutral**:
- `fatalError` on launch failure is replaced by an error screen, so `AppEnvironment.launch()` changes signature.
- Shuffling happens once in the feature model (feature 6 spec decides exactly when an exercise first counts as shown).
- Timestamps are UTC; any "today" logic (streaks, due today) must convert to the local day, decided by the slice that needs it.

## Follow-up

- [ ] Feature 4 spec (Claude Code bridge): produce `NewLesson` and `NewGeneration` (`promptVersion`, `model`, `rawReply`, `durationMs`) from a validated reply.
- [ ] Feature 6 spec (first lesson loop): decide when an exercise counts as shown (the moment `saveDisplayOrder` is called), how `fillBlank` and `translate` are graded (app vs Claude), and whether retries are offered inline.
- [ ] Feature 12 spec (review): choose the scheduler (SM-2, FSRS, or other) whose state fills `reviewItem.schedulerState`.
- [ ] Slice 2 to 6 specs: each writes its own additive migration from the target table above; a breaking change to a Slice 1 table needs its own spec.
- [ ] Revisit storage growth (raw replies, attempts) only if the database passes about 100 MB.
- [ ] Deferred backup/export/sync: UUID keys are in place; the export format is its own decision.
