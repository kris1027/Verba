/// Saves and reads lessons and answers. Offers archive, never delete.
public protocol LessonStore: Sendable {
    /// Saves a generated lesson and the Claude call behind it, all or nothing, in the `ready` state.
    func saveGeneratedLesson(_ lesson: NewLesson, generation: NewGeneration) async throws(StoreError) -> LessonDetail

    /// Reads a lesson by id, archived or not.
    func lesson(_ id: LessonID) async throws(StoreError) -> LessonDetail

    /// The lesson now, then again after every change. Finishes at once if the id is missing, or on a database error.
    func observeLesson(_ id: LessonID) async -> AsyncStream<LessonDetail>

    /// The course's unarchived lessons, newest first, then again after every change. Finishes on a database error.
    func observeLessons(course: CourseID) async -> AsyncStream<[LessonSummary]>

    /// Saves an exercise's shuffled option order, once. A second save throws and keeps the stored order.
    func saveDisplayOrder(_ order: [ExercisePartID], for exercise: ExerciseID) async throws(StoreError)

    /// Saves an answer, numbers it, and moves the lesson forward.
    func recordAttempt(_ attempt: NewAttempt) async throws(StoreError) -> Attempt

    /// Hides a lesson from lists. Does nothing if it is already archived.
    func archiveLesson(_ id: LessonID) async throws(StoreError)
}
