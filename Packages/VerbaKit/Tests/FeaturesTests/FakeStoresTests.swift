import Testing

@testable import Core

/// The fakes must keep the same contract as the real store, or feature tests prove nothing.
struct FakeStoresTests {
    private let generation = NewGeneration(kind: .lesson, model: nil, promptVersion: "1", rawReply: "{}", durationMs: 1)

    private struct Stores {
        let learner: FakeLearnerStore
        let lesson: FakeLessonStore
        let course: Course
    }

    private func makeStores() async throws -> Stores {
        let learner = FakeLearnerStore()
        let course = try await learner.addCourse(target: LanguageTag("es"), native: LanguageTag("pl"))
        return Stores(learner: learner, lesson: FakeLessonStore(courses: learner), course: course)
    }

    private func oneExerciseLesson(in courseID: CourseID, parts: [NewExercisePart]) throws -> NewLesson {
        try NewLesson(
            courseID: courseID, title: "Greetings", topic: "Hello", explanation: "Say hello.",
            exercises: [NewExercise(kind: .choice, prompt: "Hello?", parts: parts)])
    }

    private let twoOptions = [
        NewExercisePart(text: "a", isCorrect: true),
        NewExercisePart(text: "b", isCorrect: false),
    ]

    @Test func learnerIsCreatedOnce() async throws {
        let store = FakeLearnerStore()
        let first = try await store.loadOrCreateLearner()
        let second = try await store.loadOrCreateLearner()
        #expect(first.id == second.id)
    }

    @Test func aSecondCourseForTheSameLanguageIsRejected() async throws {
        let store = FakeLearnerStore()
        let spanish = try LanguageTag("es")
        let polish = try LanguageTag("pl")
        _ = try await store.addCourse(target: spanish, native: polish)
        await #expect(throws: StoreError.duplicateCourse) {
            try await store.addCourse(target: spanish, native: polish)
        }
    }

    @Test func answeringTheOnlyExerciseCompletesTheLesson() async throws {
        let stores = try await makeStores()
        let lesson = try oneExerciseLesson(in: stores.course.id, parts: twoOptions)
        let saved = try await stores.lesson.saveGeneratedLesson(lesson, generation: generation)

        _ = try await stores.lesson.recordAttempt(
            NewAttempt(
                exerciseID: saved.exercises[0].id, response: .choice(twoOptions[0].id), grade: .correct,
                feedback: "Yes.", gradedBy: .app))

        let reread = try await stores.lesson.lesson(saved.id)
        #expect(reread.lesson.state == .completed)
        #expect(reread.score.firstTryCorrect == 1)
    }

    @Test func aDisplayOrderIsSavedOnce() async throws {
        let stores = try await makeStores()
        let lesson = try oneExerciseLesson(in: stores.course.id, parts: twoOptions)
        let saved = try await stores.lesson.saveGeneratedLesson(lesson, generation: generation)
        let exercise = saved.exercises[0].id
        let (first, second) = (twoOptions[0].id, twoOptions[1].id)

        try await stores.lesson.saveDisplayOrder([second, first], for: exercise)

        await #expect(throws: StoreError.displayOrderAlreadySet) {
            try await stores.lesson.saveDisplayOrder([first, second], for: exercise)
        }
        #expect(try await stores.lesson.lesson(saved.id).exercises[0].parts.map(\.id) == [second, first])
    }

    @Test func aLessonForAMissingCourseIsRejected() async throws {
        let stores = try await makeStores()
        let lesson = try oneExerciseLesson(in: CourseID(), parts: twoOptions)
        await #expect(throws: StoreError.notFound) {
            try await stores.lesson.saveGeneratedLesson(lesson, generation: generation)
        }
    }

    @Test func aLessonForAnArchivedCourseIsRejected() async throws {
        let stores = try await makeStores()
        try await stores.learner.archiveCourse(stores.course.id)
        let lesson = try oneExerciseLesson(in: stores.course.id, parts: twoOptions)
        await #expect(throws: StoreError.archived) {
            try await stores.lesson.saveGeneratedLesson(lesson, generation: generation)
        }
    }

    @Test func anInvalidLessonIsRejected() async throws {
        let stores = try await makeStores()
        let empty = NewLesson(
            unchecked: LessonID(), courseID: stores.course.id, kind: .regular, title: "T", topic: "T", explanation: "E",
            exercises: [])
        await #expect(throws: StoreError.invalid(.emptyLesson)) {
            try await stores.lesson.saveGeneratedLesson(empty, generation: generation)
        }
    }

    @Test func anOpenLessonListUpdatesAfterASaveAndAnArchive() async throws {
        let stores = try await makeStores()
        var updates = await stores.lesson.observeLessons(course: stores.course.id).makeAsyncIterator()
        #expect(await updates.next()?.isEmpty == true)

        let lesson = try oneExerciseLesson(in: stores.course.id, parts: twoOptions)
        let saved = try await stores.lesson.saveGeneratedLesson(lesson, generation: generation)
        #expect(await updates.next()?.map(\.id) == [saved.id])

        try await stores.lesson.archiveLesson(saved.id)
        #expect(await updates.next()?.isEmpty == true)
    }
}
