import Core
import Testing

/// The fakes must keep the same contract as the real store, or feature tests prove nothing.
struct FakeStoresTests {
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
        let store = FakeLessonStore()
        let right = NewExercisePart(text: "hola", isCorrect: true)
        let lesson = try NewLesson(
            courseID: CourseID(), title: "Greetings", topic: "Hello", explanation: "Say hello.",
            exercises: [
                NewExercise(
                    kind: .choice, prompt: "Hello?", parts: [right, NewExercisePart(text: "adiós", isCorrect: false)])
            ])
        let saved = try await store.saveGeneratedLesson(
            lesson,
            generation: NewGeneration(kind: .lesson, model: nil, promptVersion: "1", rawReply: "{}", durationMs: 1))

        _ = try await store.recordAttempt(
            NewAttempt(
                exerciseID: saved.exercises[0].id, response: .choice(right.id), grade: .correct, feedback: "Yes.",
                gradedBy: .app))

        let reread = try await store.lesson(saved.id)
        #expect(reread.lesson.state == .completed)
        #expect(reread.score.firstTryCorrect == 1)
    }

    @Test func aDisplayOrderIsSavedOnce() async throws {
        let store = FakeLessonStore()
        let parts = [NewExercisePart(text: "a", isCorrect: true), NewExercisePart(text: "b", isCorrect: false)]
        let lesson = try NewLesson(
            courseID: CourseID(), title: "T", topic: "T", explanation: "E",
            exercises: [NewExercise(kind: .choice, prompt: "P", parts: parts)])
        let saved = try await store.saveGeneratedLesson(
            lesson,
            generation: NewGeneration(kind: .lesson, model: nil, promptVersion: "1", rawReply: "{}", durationMs: 1))
        let exercise = saved.exercises[0].id

        try await store.saveDisplayOrder([parts[1].id, parts[0].id], for: exercise)

        await #expect(throws: StoreError.displayOrderAlreadySet) {
            try await store.saveDisplayOrder([parts[0].id, parts[1].id], for: exercise)
        }
        #expect(try await store.lesson(saved.id).exercises[0].parts.map(\.id) == [parts[1].id, parts[0].id])
    }
}
