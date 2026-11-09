# Verify: Data model · spec 0002 · updated 2026-11-09
_Steps derived from spec 0002 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

`DEV` below means `~/Library/Application Support/Verba-Dev`. These steps use only the dev data folder, never your real one.

## UI / manual
- [x] Build and open `Verba Dev.app` with a healthy database → the normal window appears, with no error screen → AC-12
- [x] Quit the app. Move `DEV/verba.sqlite` and its `-wal` and `-shm` files somewhere safe, fill a new `DEV/verba.sqlite` with random bytes (`head -c 8192 /dev/urandom > verba.sqlite`), note its checksum, and open the app → the error screen shows a plain English message, **Show Database in Finder**, and **Quit**, with no crash → AC-12
- [x] On that screen, press **Show Database in Finder** → Finder opens with `verba.sqlite` selected → AC-12
- [x] Press **Quit**, then compare the checksum of `DEV/verba.sqlite` → unchanged → AC-12
- [x] Quit, delete the fake file and its side files, run `chmod 555 "DEV"`, and open the app → the same screen appears, and **Show Database in Finder** selects the data folder because the file does not exist. Run `chmod 755 "DEV"` afterwards → AC-12
- [x] Put your original files back and open the app → the normal window returns → AC-12
- [x] Turn on VoiceOver on the error screen → the message and both buttons are read and labelled; the screen stays usable at a larger text size → AC-12

## Commands
- [x] `swift test --package-path Packages/VerbaKit` → every test passes → AC-1 to AC-11, AC-13, AC-14
- [x] `swift format lint --strict --recursive App Packages/VerbaKit/Sources Packages/VerbaKit/Tests && swiftlint lint --strict` → no findings, including the rule that keeps GRDB out of `Features` → AC-2
- [x] `sqlite3 "DEV/verba.sqlite" "select identifier from grdb_migrations"` → `v0_scaffold` then `v1_core` → AC-1
- [x] `sqlite3 "DEV/verba.sqlite" ".schema"` → exactly the seven tables, their `CHECK`s, and the partial index on `displayPosition` from the spec → AC-1
- [x] `ls "DEV/backups"` after the first launch on an older file → one `verba-<UTC time>.sqlite`, which still holds only `v0_scaffold` → AC-11

## Value sourcing
- [x] Learner id and `createdAt` → the store makes them on the first call, and later calls return the same ones (`tenConcurrentFirstCallsCreateOneLearner`, `theLearnerSurvivesAReopen`) → AC-4
- [x] Target and native language → stored exactly as the canonical `LanguageTag` values passed in; try `pt-br` and expect `pt-BR`, and two courses with different native languages (`coursesCanHaveDifferentNativeLanguages`) → AC-5, AC-6
- [x] Lesson, exercise, and part ids → the ids built in `NewLesson` are the ids read back (`aLessonReadsBackEqualAfterClosingTheFile`) → AC-2
- [x] Title, topic, explanation, prompts, part texts and roles → read back equal to what `NewLesson` carried → AC-2
- [x] `promptVersion`, `model`, `rawReply`, `durationMs` → read back equal to what `NewGeneration` carried, in `LessonDetail.generation` → AC-2
- [x] `state = ready` and `createdAt` → set by the store on save, whatever the caller passes (`savingSetsReadyAndKeepsClaudesOrder`) → AC-7
- [x] `displayPosition` → the order from `OptionShuffler`, saved once; a second save with another order keeps the first (`aSecondDisplayOrderIsRefusedAndTheFirstKept`) → AC-9
- [x] `attemptNumber` → one more than the highest for that exercise, with no gaps under twenty concurrent saves (`twentyConcurrentAttemptsAreNumberedWithoutGaps`) → AC-8
- [x] `grade`, `feedback`, `gradedBy` → stored as given; `Grader` returns the grade for `choice`, `reorder`, and `match`, and nil for `fillBlank` and `translate` (`GraderTests`) → AC-14
- [x] `answeredAt`, `startedAt`, `completedAt`, new `state` → both timestamps equal the attempt that changed the state, including a one exercise lesson (`theFirstAttemptStartsAndTheLastCompletes`, `aOneExerciseLessonCompletesOnItsFirstAttempt`) → AC-7
- [x] `LessonScore` → counts first attempts graded `correct` only; a later correct attempt changes nothing, and it agrees between `lesson` and `observeLessons` (`attemptsAfterCompletionChangeNothingOnTheLesson`, `anOpenListUpdatesAfterAnAttemptAndAnArchive`) → AC-8
- [x] `Generation` on a lesson → the row named by `lesson.generationId` → AC-2
- [x] Option order on reopen → `displayPosition` once set, else `sourcePosition`; check both before and after a save → AC-2, AC-9
- [x] Backup file name → current UTC time with no colons, even when your Mac is in another time zone; a clash adds `-2` (`aNameClashGetsASuffix`) → AC-11
- [x] Error screen message and location → `PersistenceError.errorDescription` (or the folder error's description), and the file, or the data folder when the file is missing → AC-12

## Acceptance criteria coverage
- AC-1: `SchemaTests`, the `sqlite3` steps
- AC-2: `aLessonReadsBackEqualAfterClosingTheFile`, `storedDatesReadBackExactly`
- AC-3: `aFailedSaveLeavesNothingBehind`, `aLessonForAMissingCourseThrowsNotFound`
- AC-4: `LearnerStoreTests`
- AC-5: `aSecondCourseForALanguageIsRejected`, `coursesCanHaveDifferentNativeLanguages`
- AC-6: `LanguageTagTests`, `theSameTargetAndNativeIsRejectedWithNoLearnerLeftBehind`
- AC-7: `LessonStateTests`, the attempt state tests in `LessonStoreTests`
- AC-8: `LessonScoreTests`, `twentyConcurrentAttemptsAreNumberedWithoutGaps`
- AC-9: `OptionShufflerTests`, the display order tests in `LessonStoreTests`
- AC-10: the archive tests in `LearnerStoreTests` and `LessonStoreTests`, `aRawDeleteOfALessonWithExercisesFails`
- AC-11: `OpenAndBackupTests`, the `ls` step
- AC-12: `OpenAndBackupTests` for the store; the UI / manual steps for the screen, because the app target has no test target yet
- AC-13: `LessonLiveReadTests`, `observeCoursesDeliversCurrentThenUpdates`
- AC-14: `GraderTests`, `aResponseThatDoesNotFitIsRejectedAndNotSaved`
