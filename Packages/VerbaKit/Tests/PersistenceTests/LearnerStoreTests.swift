import Core
import Foundation
import GRDB
import Testing

@testable import Persistence

struct LearnerStoreTests {
    private let store: AppDatabase
    private let spanish: LanguageTag
    private let polish: LanguageTag

    init() throws {
        store = try AppDatabase.inMemory()
        spanish = try LanguageTag("es")
        polish = try LanguageTag("pl")
    }

    @Test func theLearnerSurvivesAReopen() async throws {
        try await withTemporaryPaths { paths in
            let database = try AppDatabase.open(paths)
            let learner = try await database.loadOrCreateLearner()
            try database.close()

            let reopened = try await AppDatabase.open(paths).loadOrCreateLearner()
            #expect(reopened == learner)
        }
    }

    @Test func tenConcurrentFirstCallsCreateOneLearner() async throws {
        try await withTemporaryPaths { paths in
            let database = try AppDatabase.open(paths)
            let ids = try await withThrowingTaskGroup(of: LearnerID.self) { group in
                for _ in 0..<10 {
                    group.addTask { try await database.loadOrCreateLearner().id }
                }
                return try await group.reduce(into: Set<LearnerID>()) { $0.insert($1) }
            }
            #expect(ids.count == 1)
            let rows = try await database.writer.read { db in try LearnerRow.fetchCount(db) }
            #expect(rows == 1)
        }
    }

    @Test(arguments: [("  Kris ", "Kris"), ("   ", nil), (nil, nil)] as [(String?, String?)])
    func displayNameIsTrimmed(input: String?, expected: String?) async throws {
        _ = try await store.loadOrCreateLearner()
        #expect(try await store.setDisplayName(input).displayName == expected)
    }

    @Test func settingANameWithNoLearnerThrows() async throws {
        await #expect(throws: StoreError.notFound) {
            try await store.setDisplayName("Kris")
        }
    }

    @Test func addingACourseCreatesTheLearnerIfNeeded() async throws {
        let course = try await store.addCourse(target: spanish, native: polish)
        #expect(try await store.loadOrCreateLearner().id == course.learnerID)
        #expect(course.targetLanguage == spanish && course.nativeLanguage == polish)
    }

    @Test func aSecondCourseForALanguageIsRejected() async throws {
        _ = try await store.addCourse(target: spanish, native: polish)
        let english = try LanguageTag("en")
        await #expect(throws: StoreError.duplicateCourse) {
            try await store.addCourse(target: spanish, native: english)
        }
    }

    @Test func coursesCanHaveDifferentNativeLanguages() async throws {
        let english = try LanguageTag("en")
        _ = try await store.addCourse(target: spanish, native: polish)
        _ = try await store.addCourse(target: try LanguageTag("fr"), native: english)
        #expect(try await store.courses().map(\.nativeLanguage) == [polish, english])
    }

    @Test func theSameTargetAndNativeIsRejectedWithNoLearnerLeftBehind() async throws {
        await #expect(throws: StoreError.invalid(.sameLanguage)) {
            try await store.addCourse(target: polish, native: polish)
        }
        let rows = try await store.writer.read { db in try LearnerRow.fetchCount(db) }
        #expect(rows == 0)
    }

    @Test func archivingHidesACourseAndIsIdempotent() async throws {
        let course = try await store.addCourse(target: spanish, native: polish)

        try await store.archiveCourse(course.id)
        let archivedAt = try await store.courses(includeArchived: true)[0].archivedAt
        try await store.archiveCourse(course.id)

        #expect(archivedAt != nil)
        #expect(try await store.courses(includeArchived: true)[0].archivedAt == archivedAt)
        #expect(try await store.courses().isEmpty)
    }

    @Test func anArchivedLanguageIsADuplicateUntilUnarchived() async throws {
        let course = try await store.addCourse(target: spanish, native: polish)
        try await store.archiveCourse(course.id)

        await #expect(throws: StoreError.duplicateCourse) {
            try await store.addCourse(target: spanish, native: polish)
        }

        #expect(try await store.unarchiveCourse(course.id).archivedAt == nil)
        #expect(try await store.courses().map(\.id) == [course.id])
    }

    @Test func archivingAMissingCourseThrows() async throws {
        await #expect(throws: StoreError.notFound) {
            try await store.archiveCourse(CourseID())
        }
        await #expect(throws: StoreError.notFound) {
            try await store.unarchiveCourse(CourseID())
        }
    }

    @Test(.timeLimit(.minutes(1))) func observeCoursesDeliversCurrentThenUpdates() async throws {
        let stream = await store.observeCourses()
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next() == [])

        let course = try await store.addCourse(target: spanish, native: polish)

        let updated = await Sample.firstValue(from: stream) { $0.map(\.id) == [course.id] }
        #expect(updated != nil)
    }
}
