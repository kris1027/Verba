/// Saves and reads the learner and their courses. Offers archive and unarchive, never delete.
public protocol LearnerStore: Sendable {
    /// Returns the one learner, creating it on the first call.
    func loadOrCreateLearner() async throws(StoreError) -> Learner

    /// Sets the learner's name. The name is trimmed, and an empty name becomes nil.
    func setDisplayName(_ name: String?) async throws(StoreError) -> Learner

    /// Adds a course for a language, creating the learner first if needed.
    func addCourse(target: LanguageTag, native: LanguageTag) async throws(StoreError) -> Course

    /// The learner's courses, oldest first.
    func courses(includeArchived: Bool) async throws(StoreError) -> [Course]

    /// The unarchived courses now, then again after every change. Finishes on a database error.
    func observeCourses() async -> AsyncStream<[Course]>

    /// Hides a course from lists. Does nothing if it is already archived.
    func archiveCourse(_ id: CourseID) async throws(StoreError)

    /// Brings an archived course back. Does nothing if it is not archived.
    func unarchiveCourse(_ id: CourseID) async throws(StoreError) -> Course
}

extension LearnerStore {
    /// The learner's unarchived courses, oldest first.
    public func courses() async throws(StoreError) -> [Course] {
        try await courses(includeArchived: false)
    }
}
