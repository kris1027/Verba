# 0002. Data model: rationale

The decision record behind [index.md](index.md). `/develop` builds from `index.md`; this file explains why.

## Context

Verba keeps everything on one Mac in a single SQLite file opened through GRDB (spec [0001](../0001-stack-architecture/index.md)). Migrations only move forward: each schema change is a new, named migration appended after the scaffold's `v0_scaffold`, and an applied migration is never edited. That rule makes the first real schema load bearing. A table shaped wrong now is either lived with for every later slice or fixed with a SQLite table rebuild migration over real learning history.

The product spans nine slices that all write to this file: a first lesson loop, goals and levels with a placement check, progress and history, tutor chat, learner memory, spaced review, a reference notebook, several languages per learner, then pronunciation and speaking. The scope's done line asks that the shape already fit those slices "without a breaking migration," while the Tracer Bullet approach asks that each slice stay thin and run end to end before the next one thickens it.

The teaching principles put specific demands on storage. "Proof, not coverage" means learner memory needs evidence it can point at: a specific answer or a specific chat correction. "Fair quizzes" means the app, not Claude, shuffles options, and a reopened lesson should show what you actually saw. "Long term memory over the feeling of fluency" means the first try is what counts, and review must schedule items by a due time across topics. Records are "marked replaced, not deleted," so history is never lost.

Practical forces: one learner, personal scale (thousands of rows, not millions), Swift 6 strict concurrency with `Sendable` Core value types at every module boundary, no GRDB type outside `Persistence`, and a lesson format coming from an LLM whose exact shape will keep evolving as prompts improve.

## Options considered

### Option 1: Store each lesson as one JSON document

A `lesson` table with a few header columns and a `content` JSON column holding Claude's whole reply (explanation, exercises, options), plus an `answers` JSON column. Later slices add their own tables but read lesson content by decoding the document.

**Pros**:
- Least code to first lesson: one record type, the reply saved nearly as is.
- Lesson format changes need no migration.

**Cons**:
- Grading, saved shuffle order, scoring, review, learner memory evidence, and notebook links all need to reach inside JSON; SQLite cannot index, constrain, or foreign key into it.
- "Every attempt kept" and "a record points at its proof" have nothing stable to point at.
- Bugs in the document shape surface only at read time, often slices later.

### Option 2: One designed target schema, created slice by slice (chosen)

Normalized tables with real columns for everything the app grades, shuffles, lists, or schedules; text or JSON only for content shown but never queried (explanation Markdown, the raw reply, an attempt's response, scheduler state). The whole target is designed now; this feature migrates the seven Slice 1 tables, and each later slice adds its own tables or nullable columns in a new migration.

**Pros**:
- Constraints and foreign keys enforce the teaching rules (unique attempt numbers, display order, proof links) in the database itself.
- Later slices have a known, additive landing spot; no slice waits on another's tables.
- Tables are created only when the slice that uses them is designed, so their columns can still be refined by that slice's spec.

**Cons**:
- More code up front: record structs, mapping, and per kind part rules.
- The target for later slices is a sketch; a later spec can still need a column change, which then costs a rebuild migration.

### Option 3: Create the full nineteen table schema now

The same normalized design as Option 2, but all tables created in one migration in this feature.

**Pros**:
- One migration, one schema snapshot to reason about.
- Every later slice starts with its tables in place.

**Cons**:
- Columns for chat, memory, review, and notebook are fixed before those features are designed; any change later is an edit to an applied migration (forbidden) or a rebuild.
- Unused tables sit in the file for months with no code exercising their constraints, so mistakes stay hidden.

### Option 4: Fully normalized content

Like Option 2, but the explanation is also split into rows (blocks, examples, tables), and grading feedback into structured fields.

**Pros**:
- Every piece of a lesson is queryable, which a richer notebook could use.

**Cons**:
- The explanation format follows the prompt, which will change often; every change becomes a migration.
- Many more tables and joins for content the app only renders.

## Rationale

Option 2 is the only one that serves both sides of the scope's done line. The forward only migration rule from spec 0001 makes each table permanent once applied, which argues against Option 3: designing chat, memory, and review columns now and locking them into an applied migration means those slices inherit guesses. Designing the whole target now, but applying only what Slice 1 exercises, keeps the guarantee that later slices land additively while letting each slice's own spec refine its tables before they become permanent. It also fits Tracer Bullet: Slice 1's thread runs through real tables, and every later strand thickens it with its own migration.

Option 1 fails the teaching principles directly. Proof needs a stable row to point at (an attempt, a correction), the fair quiz rule needs a saved display position per option, and the first try rule needs numbered attempts; none of these can be enforced or indexed inside a JSON document. The hybrid boundary in Option 2 (real columns for what the app decides on, Markdown for what it only shows) also answers Option 4: the explanation's internal shape belongs to the prompt in feature 4 spec, not the schema, so it stays one text column, while everything the app's rules touch stays relational. Keeping the raw reply in `generation` covers the remaining risk: a lesson that parsed wrong can be inspected or parsed again without asking Claude.

The smaller calls follow the same forces. UUID text keys let Core build a complete `NewLesson` with identity before it is saved and keep the deferred export and sync feature open; at personal scale their cost over integers is not measurable. Typed nullable proof links (rather than a generic source pair) let SQLite enforce that evidence exists. Archive instead of delete, with `ON DELETE RESTRICT`, makes the "replaced, not deleted" principle a database guarantee rather than a convention. The backup before migrating is cheap insurance for a file that will see at least six more migrations over real progress, and failing closed when it cannot be written follows from the same goal: never risk the history.

## Decisions settled during the conversation

Asked and answered by you:

| Question | Answer |
|---|---|
| Learners per install | One learner, no profiles |
| How much to migrate now | Full target design, Slice 1 tables now |
| Deleting things | Archive, never hard delete history |
| Lesson storage | Hybrid: rows for what the app queries, Markdown explanation |
| Native language | Per course |
| Language ids | BCP 47 tags as text |
| Primary keys | UUID text |
| Attempts | Every attempt, in order |
| Option order on reopen | Shuffle once, save the order |
| Level | Current level plus a change log (Slice 2) |
| Goal | Columns on the course, edit overwrites (Slice 2) |
| Review scheduling room | `dueAt` plus scheduler state as JSON (Slice 5) |
| Exercise kinds | choice, fill in the blank, translate, reorder, match |
| Lesson states | ready, inProgress, completed |
| Teaching preferences | Per course, or every language when the course is empty |
| Chat corrections | Correction rows linked to the message |
| Proof links | Typed nullable links with a check |
| Notebook | Page per topic, many lessons link to it |
| Lesson links | Link table, many to many |
| Reorder and match parts | One parts table with role columns |
| Raw replies | Kept in a `generation` table |
| Vocabulary | Its own table, linked to the proving record |
| Placement check | A lesson with kind `placement` |
| Stated prior knowledge | Learning records of kind `stated` |
| Store protocols | One per area |
| Database fails to open | Error screen, never erase |
| Backup before migrating | Yes, keep the newest 3 |
| Editing a learning record | A new record replaces the old |
| Which attempt scores | The first; a later correct one is a fix |
| Learner name | Optional display name |

Settled by the architect (pick, why, runner up):

| Item | Pick | Why | Runner up |
|---|---|---|---|
| Naming | camelCase tables and columns | Matches GRDB `Codable` mapping, no coding keys | snake_case |
| Record mapping | Internal GRDB row structs mapped to Core types | Keeps GRDB out of Core's public surface | Retroactive conformances on Core types |
| Ids in Core | Generic phantom `ID<Entity>` | Type safe with no per entity boilerplate | One struct per entity |
| Score | Computed at read time from attempt 1 | Never stale; trivially cheap at this scale | Stored on completion |
| Check constraints | Only on closed sets (state, grade, gradedBy) | Open kinds grow without a rebuild migration | Checks on every enum column |
| Attempt answer | One JSON `response` column (`AttemptResponse`) | Four kinds of answer, never filtered by | A column per answer kind |
| Errors | `ValidationError` and `StoreError` in Core, typed throws | Features can show messages without importing Persistence | Errors declared in Persistence |
| Live reads on failure | Log and finish the stream | Matches the `AsyncStream` rule in AGENTS.md | `AsyncThrowingStream` |
| Backup failure | Fail closed (no migration) | Never risk history on an unbacked migration | Migrate anyway and log |
| Timestamps | UTC, GRDB default text encoding | Readable in any SQLite tool, sortable | Unix epoch numbers |

Added after the cross check (another model read the draft; you chose to apply its recommended fixes):

| Item | Pick | Why |
|---|---|---|
| Lesson state rule | Pure `advanced`, no transition error; empty lessons rejected; one exercise lessons complete on the first attempt | The store drives the state, so an error path could never fire |
| Save failure mapping | One `mapError` helper: parent foreign key → `notFound`, course unique → `duplicateCourse`, else `unavailable` | Makes AC-3's errors testable |
| Display order | Exact set of displayed parts; second save throws and keeps the order; partial unique index | The database itself guarantees a real permutation |
| Round trip | Dates rounded to the millisecond; `LessonDetail` carries its `Generation` | GRDB stores milliseconds, so equality must hold after a reopen |
| Single learner | Select and insert in one write transaction | Two first launches cannot race |
| Archived courses | `unarchiveCourse`; archived rows take no new lessons or attempts; archive is idempotent | Re adding an archived language no longer strands you |
| Live streams | Current value first, newest only buffer, `values(in:)` bridge | Defined behavior for screens and tests |
| App grading | Pure Core `Grader` for choice, reorder, match; response shape validated | The "correct when" rules needed an owner |
| Lesson timestamp checks | Table `CHECK`s in `v1_core` | Cannot be added later without a rebuild |
| Launch failure | `LaunchResult`, error screen also for `prepareFolders`; only the main file's bytes are promised unchanged | SQLite may add WAL side files on open |
