import Core
import Foundation

/// An in memory `LearnerStore` for feature model tests.
actor FakeLearnerStore: LearnerStore {
    private var learner: Learner?
    private var stored: [Course] = []
    private var observers: [UUID: AsyncStream<[Course]>.Continuation] = [:]

    func loadOrCreateLearner() -> Learner {
        if let learner { return learner }
        let created = Learner(id: LearnerID(), displayName: nil, createdAt: .now)
        learner = created
        return created
    }

    func setDisplayName(_ name: String?) throws(StoreError) -> Learner {
        guard let current = learner else { throw .notFound }
        let updated = Learner(
            id: current.id, displayName: Learner.normalizedDisplayName(name), createdAt: current.createdAt)
        learner = updated
        return updated
    }

    func addCourse(target: LanguageTag, native: LanguageTag) throws(StoreError) -> Course {
        do {
            try Course.validateLanguages(target: target, native: native)
        } catch {
            throw .invalid(error)
        }
        guard !stored.contains(where: { $0.targetLanguage == target }) else { throw .duplicateCourse }
        let course = Course(
            id: CourseID(), learnerID: loadOrCreateLearner().id, targetLanguage: target, nativeLanguage: native,
            createdAt: .now, archivedAt: nil)
        stored.append(course)
        publish()
        return course
    }

    func courses(includeArchived: Bool) -> [Course] {
        includeArchived ? stored : stored.filter { $0.archivedAt == nil }
    }

    func observeCourses() -> AsyncStream<[Course]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [Course].self, bufferingPolicy: .bufferingNewest(1))
        observers[UUID()] = continuation
        continuation.yield(courses(includeArchived: false))
        return stream
    }

    func archiveCourse(_ id: CourseID) throws(StoreError) {
        try replaceCourse(id) { $0.archivedAt == nil ? .now : $0.archivedAt }
    }

    func unarchiveCourse(_ id: CourseID) throws(StoreError) -> Course {
        try replaceCourse(id) { _ in nil }
        guard let course = stored.first(where: { $0.id == id }) else { throw .notFound }
        return course
    }

    private func replaceCourse(_ id: CourseID, archivedAt: (Course) -> Date?) throws(StoreError) {
        guard let index = stored.firstIndex(where: { $0.id == id }) else { throw .notFound }
        let old = stored[index]
        stored[index] = Course(
            id: old.id, learnerID: old.learnerID, targetLanguage: old.targetLanguage,
            nativeLanguage: old.nativeLanguage, createdAt: old.createdAt, archivedAt: archivedAt(old))
        publish()
    }

    private func publish() {
        let current = courses(includeArchived: false)
        observers.values.forEach { $0.yield(current) }
    }
}

/// An in memory `LessonStore` for feature model tests. It applies the same Core rules as the real store.
actor FakeLessonStore: LessonStore {
    private var details: [LessonID: LessonDetail] = [:]
    private var detailObservers: [LessonID: [AsyncStream<LessonDetail>.Continuation]] = [:]

    func saveGeneratedLesson(_ lesson: NewLesson, generation: NewGeneration) -> LessonDetail {
        let now = Date.now
        let exercises = lesson.exercises.enumerated().map { position, new in
            ExerciseDetail(
                exercise: Exercise(
                    id: new.id, lessonID: lesson.id, position: position, kind: new.kind, prompt: new.prompt,
                    explanation: new.explanation),
                parts: new.parts.enumerated().map { source, part in
                    ExercisePart(
                        id: part.id, exerciseID: new.id, sourcePosition: source, text: part.text, displayPosition: nil,
                        isCorrect: part.isCorrect, correctPosition: part.correctPosition, matchKey: part.matchKey)
                },
                attempts: [])
        }
        let detail = LessonDetail(
            lesson: Lesson(
                id: lesson.id, courseID: lesson.courseID, generationID: generation.id, kind: lesson.kind,
                title: lesson.title, topic: lesson.topic, explanation: lesson.explanation, state: .ready,
                createdAt: now, startedAt: nil, completedAt: nil, archivedAt: nil),
            generation: Generation(
                id: generation.id, courseID: lesson.courseID, kind: generation.kind, model: generation.model,
                promptVersion: generation.promptVersion, rawReply: generation.rawReply,
                durationMs: generation.durationMs, createdAt: now),
            exercises: exercises)
        details[lesson.id] = detail
        return detail
    }

    func lesson(_ id: LessonID) throws(StoreError) -> LessonDetail {
        guard let detail = details[id] else { throw .notFound }
        return detail
    }

    func observeLesson(_ id: LessonID) -> AsyncStream<LessonDetail> {
        let (stream, continuation) = AsyncStream.makeStream(of: LessonDetail.self, bufferingPolicy: .bufferingNewest(1))
        guard let detail = details[id] else {
            continuation.finish()
            return stream
        }
        detailObservers[id, default: []].append(continuation)
        continuation.yield(detail)
        return stream
    }

    func observeLessons(course: CourseID) -> AsyncStream<[LessonSummary]> {
        let summaries = details.values
            .filter { $0.lesson.courseID == course && $0.lesson.archivedAt == nil }
            .sorted { $0.lesson.createdAt > $1.lesson.createdAt }
            .map {
                LessonSummary(
                    id: $0.id, title: $0.lesson.title, topic: $0.lesson.topic, state: $0.lesson.state,
                    createdAt: $0.lesson.createdAt, completedAt: $0.lesson.completedAt, score: $0.score)
            }
        let (stream, continuation) = AsyncStream.makeStream(of: [LessonSummary].self)
        continuation.yield(summaries)
        return stream
    }

    func saveDisplayOrder(_ order: [ExercisePartID], for exercise: ExerciseID) throws(StoreError) {
        let (detail, index) = try locate(exercise)
        let current = detail.exercises[index]
        guard current.parts.allSatisfy({ $0.displayPosition == nil }) else { throw .displayOrderAlreadySet }
        do {
            try OptionShuffler.validate(order: order, kind: current.exercise.kind, parts: current.parts)
        } catch {
            throw .invalid(error)
        }
        let reordered = order.enumerated().compactMap { position, id -> ExercisePart? in
            guard let part = current.parts.first(where: { $0.id == id }) else { return nil }
            return ExercisePart(
                id: part.id, exerciseID: part.exerciseID, sourcePosition: part.sourcePosition, text: part.text,
                displayPosition: position, isCorrect: part.isCorrect, correctPosition: part.correctPosition,
                matchKey: part.matchKey)
        }
        store(detail, replacing: index, with: reordered, attempts: current.attempts, lesson: detail.lesson)
    }

    func recordAttempt(_ attempt: NewAttempt) throws(StoreError) -> Attempt {
        let (detail, index) = try locate(attempt.exerciseID)
        guard detail.lesson.archivedAt == nil else { throw .archived }
        let current = detail.exercises[index]
        do {
            try Grader.validate(attempt.response, kind: current.exercise.kind, parts: current.parts)
        } catch {
            throw .invalid(error)
        }
        let saved = Attempt(
            id: attempt.id, exerciseID: attempt.exerciseID, attemptNumber: current.attempts.count + 1,
            response: attempt.response, grade: attempt.grade, feedback: attempt.feedback, gradedBy: attempt.gradedBy,
            answeredAt: .now)
        let answered = detail.exercises.enumerated().count { $0.offset == index || !$0.element.attempts.isEmpty }
        let old = detail.lesson
        let state = old.state.advanced(exerciseCount: detail.exercises.count, answeredCount: answered)
        let lesson = Lesson(
            id: old.id, courseID: old.courseID, generationID: old.generationID, kind: old.kind, title: old.title,
            topic: old.topic, explanation: old.explanation, state: state, createdAt: old.createdAt,
            startedAt: old.startedAt ?? saved.answeredAt,
            completedAt: old.completedAt ?? (state == .completed ? saved.answeredAt : nil), archivedAt: old.archivedAt)
        store(detail, replacing: index, with: current.parts, attempts: current.attempts + [saved], lesson: lesson)
        return saved
    }

    func archiveLesson(_ id: LessonID) throws(StoreError) {
        guard let detail = details[id] else { throw .notFound }
        guard detail.lesson.archivedAt == nil else { return }
        let old = detail.lesson
        let lesson = Lesson(
            id: old.id, courseID: old.courseID, generationID: old.generationID, kind: old.kind, title: old.title,
            topic: old.topic, explanation: old.explanation, state: old.state, createdAt: old.createdAt,
            startedAt: old.startedAt, completedAt: old.completedAt, archivedAt: .now)
        publish(LessonDetail(lesson: lesson, generation: detail.generation, exercises: detail.exercises))
    }

    private func locate(_ exercise: ExerciseID) throws(StoreError) -> (LessonDetail, Int) {
        for detail in details.values {
            if let index = detail.exercises.firstIndex(where: { $0.id == exercise }) {
                return (detail, index)
            }
        }
        throw .notFound
    }

    private func store(
        _ detail: LessonDetail, replacing index: Int, with parts: [ExercisePart], attempts: [Attempt], lesson: Lesson
    ) {
        var exercises = detail.exercises
        exercises[index] = ExerciseDetail(exercise: exercises[index].exercise, parts: parts, attempts: attempts)
        publish(LessonDetail(lesson: lesson, generation: detail.generation, exercises: exercises))
    }

    private func publish(_ detail: LessonDetail) {
        details[detail.id] = detail
        detailObservers[detail.id]?.forEach { $0.yield(detail) }
    }
}
