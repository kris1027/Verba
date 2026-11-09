import Foundation
import GRDB
import Testing

@testable import Core
@testable import Persistence

struct LessonStoreTests {
    private let store: AppDatabase

    init() throws {
        store = try AppDatabase.inMemory()
    }

    private func rowCounts() async throws -> [Int] {
        try await store.writer.read { db in
            [
                try LessonRow.fetchCount(db), try ExerciseRow.fetchCount(db), try ExercisePartRow.fetchCount(db),
                try GenerationRow.fetchCount(db),
            ]
        }
    }

    // MARK: AC-2, AC-8, AC-9: the whole thread survives a restart

    @Test func aLessonReadsBackEqualAfterClosingTheFile() async throws {
        try await withTemporaryPaths { paths in
            let database = try AppDatabase.open(paths)
            let saved = try await Sample.savedLesson(in: database)

            for exercise in saved.exercises where exercise.exercise.kind.displaysParts {
                try await database.saveDisplayOrder(exercise.parts.map(\.id).reversed(), for: exercise.id)
            }
            let shown = try await database.lesson(saved.id)
            for (index, exercise) in shown.exercises.enumerated() {
                _ = try await database.recordAttempt(Sample.answer(exercise, grade: index == 0 ? .correct : .wrong))
            }
            let expected = try await database.lesson(saved.id)
            try database.close()

            let reopened = try await AppDatabase.open(paths).lesson(saved.id)

            #expect(reopened == expected)
            #expect(reopened.generation?.rawReply == Sample.generation.rawReply)
            #expect(reopened.score == expected.score)
            #expect(reopened.score.firstTryCorrect == 1 && reopened.score.exerciseCount == 5)
            #expect(reopened.exercises[0].parts.map(\.text) == ["nope", "no", "right"])
        }
    }

    @Test func savingSetsReadyAndKeepsClaudesOrder() async throws {
        let detail = try await Sample.savedLesson(in: store)
        #expect(detail.lesson.state == .ready)
        #expect(detail.lesson.startedAt == nil && detail.lesson.completedAt == nil)
        #expect(detail.lesson.generationID == detail.generation?.id)
        #expect(detail.exercises.map(\.exercise.position) == [0, 1, 2, 3, 4])
        #expect(detail.exercises[0].parts.map(\.sourcePosition) == [0, 1, 2])
    }

    @Test func attemptResponsesAreStoredAsJSONText() async throws {
        let detail = try await Sample.savedLesson(in: store)
        _ = try await store.recordAttempt(Sample.answer(detail.exercises[0]))
        let type = try await store.writer.read { db in
            try String.fetchOne(db, sql: "SELECT typeof(response) FROM attempt")
        }
        #expect(type == "text")
    }

    // MARK: AC-3: all or nothing

    @Test func aFailedSaveLeavesNothingBehind() async throws {
        let course = try await Sample.course(in: store)
        let sharedID = ExercisePartID()
        let exercises = [
            NewExercise(
                kind: .choice, prompt: "P",
                parts: [
                    NewExercisePart(id: sharedID, text: "a", isCorrect: true),
                    NewExercisePart(id: sharedID, text: "b", isCorrect: false),
                ])
        ]
        let lesson = NewLesson(
            unchecked: LessonID(), courseID: course.id, kind: .regular, title: "T", topic: "T", explanation: "E",
            exercises: exercises)

        await #expect {
            try await store.saveGeneratedLesson(lesson, generation: Sample.generation)
        } throws: { error in
            guard case StoreError.unavailable = error else { return false }
            return true
        }
        #expect(try await rowCounts() == [0, 0, 0, 0])
    }

    @Test func aLessonForAMissingCourseThrowsNotFound() async throws {
        let lesson = try Sample.lesson(courseID: CourseID())
        await #expect(throws: StoreError.notFound) {
            try await store.saveGeneratedLesson(lesson, generation: Sample.generation)
        }
        #expect(try await rowCounts() == [0, 0, 0, 0])
    }

    @Test func anUncheckedEmptyLessonIsStillRejected() async throws {
        let lesson = NewLesson(
            unchecked: LessonID(), courseID: CourseID(), kind: .regular, title: "T", topic: "T", explanation: "E",
            exercises: [])
        await #expect(throws: StoreError.invalid(.emptyLesson)) {
            try await store.saveGeneratedLesson(lesson, generation: Sample.generation)
        }
    }

    // MARK: AC-7: state only moves forward

    @Test func theFirstAttemptStartsAndTheLastCompletes() async throws {
        let detail = try await Sample.savedLesson(in: store)
        let first = try await store.recordAttempt(Sample.answer(detail.exercises[0]))

        let started = try await store.lesson(detail.id).lesson
        #expect(started.state == .inProgress)
        #expect(started.startedAt == first.answeredAt)
        #expect(started.completedAt == nil)

        var last = first
        for exercise in detail.exercises.dropFirst() {
            last = try await store.recordAttempt(Sample.answer(exercise))
        }

        let finished = try await store.lesson(detail.id).lesson
        #expect(finished.state == .completed)
        #expect(finished.startedAt == first.answeredAt)
        #expect(finished.completedAt == last.answeredAt)
    }

    @Test func aOneExerciseLessonCompletesOnItsFirstAttempt() async throws {
        let detail = try await Sample.savedLesson(in: store, exercises: Sample.oneChoiceExercise())
        let attempt = try await store.recordAttempt(Sample.answer(detail.exercises[0]))

        let lesson = try await store.lesson(detail.id).lesson
        #expect(lesson.state == .completed)
        #expect(lesson.startedAt == attempt.answeredAt && lesson.completedAt == attempt.answeredAt)
    }

    @Test func attemptsAfterCompletionChangeNothingOnTheLesson() async throws {
        let detail = try await Sample.savedLesson(in: store, exercises: Sample.oneChoiceExercise())
        _ = try await store.recordAttempt(Sample.answer(detail.exercises[0], grade: .wrong))
        let finished = try await store.lesson(detail.id)

        let second = try await store.recordAttempt(Sample.answer(detail.exercises[0], grade: .correct))

        let after = try await store.lesson(detail.id)
        #expect(second.attemptNumber == 2)
        #expect(after.lesson == finished.lesson)
        #expect(after.score.firstTryCorrect == 0)
    }

    // MARK: AC-8: every attempt is kept and numbered

    @Test func twentyConcurrentAttemptsAreNumberedWithoutGaps() async throws {
        try await withTemporaryPaths { paths in
            let database = try AppDatabase.open(paths)
            let detail = try await Sample.savedLesson(in: database)
            let exercise = detail.exercises[0]

            let numbers = try await withThrowingTaskGroup(of: Int.self) { group in
                for _ in 0..<20 {
                    group.addTask { try await database.recordAttempt(Sample.answer(exercise)).attemptNumber }
                }
                return try await group.reduce(into: [Int]()) { $0.append($1) }
            }

            #expect(numbers.sorted() == Array(1...20))
            #expect(try await database.lesson(detail.id).exercises[0].attempts.map(\.attemptNumber) == Array(1...20))
        }
    }

    // MARK: AC-9: display order is saved once

    @Test func aSecondDisplayOrderIsRefusedAndTheFirstKept() async throws {
        let detail = try await Sample.savedLesson(in: store)
        let exercise = detail.exercises[0]
        let order = Array(exercise.parts.map(\.id).reversed())

        try await store.saveDisplayOrder(order, for: exercise.id)

        await #expect(throws: StoreError.displayOrderAlreadySet) {
            try await store.saveDisplayOrder(exercise.parts.map(\.id), for: exercise.id)
        }
        let reread = try await store.lesson(detail.id).exercises[0]
        #expect(reread.parts.map(\.id) == order)
        #expect(reread.parts.map(\.displayPosition) == [0, 1, 2])
    }

    @Test func invalidDisplayOrdersAreRejected() async throws {
        let detail = try await Sample.savedLesson(in: store)
        let choice = detail.exercises[0]
        let ids = choice.parts.map(\.id)
        let badOrders: [[ExercisePartID]] = [
            Array(ids.dropLast()), ids + [ExercisePartID()], [ids[0], ids[0], ids[1]],
            [ids[0], ids[1], ExercisePartID()],
        ]
        for order in badOrders {
            await #expect(throws: StoreError.invalid(.invalidDisplayOrder)) {
                try await store.saveDisplayOrder(order, for: choice.id)
            }
        }
        let translate = detail.exercises[2]
        await #expect(throws: StoreError.invalid(.invalidDisplayOrder)) {
            try await store.saveDisplayOrder(translate.parts.map(\.id), for: translate.id)
        }
        await #expect(throws: StoreError.notFound) {
            try await store.saveDisplayOrder(ids, for: ExerciseID())
        }
        #expect(try await store.lesson(detail.id).exercises[0].parts.allSatisfy { $0.displayPosition == nil })
    }

    // MARK: AC-10: nothing is deleted

    @Test func anArchivedLessonLeavesListsButStillReadsById() async throws {
        let detail = try await Sample.savedLesson(in: store)
        _ = try await store.recordAttempt(Sample.answer(detail.exercises[0]))

        try await store.archiveLesson(detail.id)
        let archivedAt = try await store.lesson(detail.id).lesson.archivedAt
        try await store.archiveLesson(detail.id)

        #expect(archivedAt != nil)
        let reread = try await store.lesson(detail.id)
        #expect(reread.lesson.archivedAt == archivedAt)
        #expect(reread.exercises[0].attempts.count == 1)
        let stream = await store.observeLessons(course: detail.lesson.courseID)
        #expect(await stream.first { _ in true } == [])
    }

    @Test func anArchivedLessonTakesNoAttempts() async throws {
        let detail = try await Sample.savedLesson(in: store)
        try await store.archiveLesson(detail.id)
        await #expect(throws: StoreError.archived) {
            try await store.recordAttempt(Sample.answer(detail.exercises[0]))
        }
    }

    @Test func anArchivedCourseTakesNoLessons() async throws {
        let course = try await Sample.course(in: store)
        try await store.archiveCourse(course.id)
        let lesson = try Sample.lesson(courseID: course.id)
        await #expect(throws: StoreError.archived) {
            try await store.saveGeneratedLesson(lesson, generation: Sample.generation)
        }
    }

    @Test func aRawDeleteOfALessonWithExercisesFails() async throws {
        let detail = try await Sample.savedLesson(in: store)
        await #expect(throws: DatabaseError.self) {
            try await store.writer.write { db in
                try db.execute(sql: "DELETE FROM lesson WHERE id = ?", arguments: [detail.id.text])
            }
        }
    }

    @Test func missingIdsThrowNotFound() async throws {
        await #expect(throws: StoreError.notFound) { try await store.lesson(LessonID()) }
        await #expect(throws: StoreError.notFound) { try await store.archiveLesson(LessonID()) }
        await #expect(throws: StoreError.notFound) {
            try await store.recordAttempt(
                NewAttempt(exerciseID: ExerciseID(), response: .text("x"), grade: .wrong, feedback: "", gradedBy: .app))
        }
    }

    // MARK: AC-14: responses must fit

    @Test func aResponseThatDoesNotFitIsRejectedAndNotSaved() async throws {
        let detail = try await Sample.savedLesson(in: store)
        let choice = detail.exercises[0]
        for response in [AttemptResponse.text("x"), .choice(detail.exercises[3].parts[0].id)] {
            await #expect(throws: StoreError.invalid(.invalidResponse)) {
                try await store.recordAttempt(
                    NewAttempt(exerciseID: choice.id, response: response, grade: .wrong, feedback: "", gradedBy: .app))
            }
        }
        #expect(try await store.lesson(detail.id).exercises[0].attempts.isEmpty)
    }
}

/// AC-13: lesson reads are live.
struct LessonLiveReadTests {
    private let store: AppDatabase

    init() throws {
        store = try AppDatabase.inMemory()
    }

    @Test(.timeLimit(.minutes(1))) func anOpenLessonUpdatesAfterAnAttempt() async throws {
        let detail = try await Sample.savedLesson(in: store)
        let stream = await store.observeLesson(detail.id)
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == detail)

        _ = try await store.recordAttempt(Sample.answer(detail.exercises[0]))

        let updated = await Sample.firstValue(from: stream) { $0.exercises[0].attempts.count == 1 }
        #expect(updated?.lesson.state == .inProgress)
    }

    @Test(.timeLimit(.minutes(1))) func anOpenLessonUpdatesAfterADisplayOrder() async throws {
        let detail = try await Sample.savedLesson(in: store)
        let stream = await store.observeLesson(detail.id)
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        try await store.saveDisplayOrder(detail.exercises[0].parts.map(\.id), for: detail.exercises[0].id)

        let updated = await Sample.firstValue(from: stream) { $0.exercises[0].parts[0].displayPosition == 0 }
        #expect(updated != nil)
    }

    @Test(.timeLimit(.minutes(1))) func anOpenListUpdatesAfterAnAttemptAndAnArchive() async throws {
        let detail = try await Sample.savedLesson(in: store)
        let stream = await store.observeLessons(course: detail.lesson.courseID)
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next()?.map(\.id) == [detail.id])

        _ = try await store.recordAttempt(Sample.answer(detail.exercises[0]))
        let scored = await Sample.firstValue(from: stream) { $0.first?.score.firstTryCorrect == 1 }
        #expect(scored?.first?.state == .inProgress)

        try await store.archiveLesson(detail.id)
        let emptied = await Sample.firstValue(from: stream) { $0.isEmpty }
        #expect(emptied != nil)
    }

    @Test(.timeLimit(.minutes(1))) func observingAMissingLessonFinishesAtOnce() async {
        let stream = await store.observeLesson(LessonID())
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }

    @Test func lessonsAreListedNewestFirst() async throws {
        let first = try await Sample.savedLesson(in: store)
        let second = try await store.saveGeneratedLesson(
            Sample.lesson(courseID: first.lesson.courseID),
            generation: Sample.generation.withNewID())
        let stream = await store.observeLessons(course: first.lesson.courseID)
        #expect(await stream.first { _ in true }?.map(\.id) == [second.id, first.id])
    }
}

extension NewGeneration {
    fileprivate func withNewID() -> NewGeneration {
        NewGeneration(
            kind: kind, model: model, promptVersion: promptVersion, rawReply: rawReply, durationMs: durationMs)
    }
}
