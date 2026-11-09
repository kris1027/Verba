import GRDB

extension AppDatabase {
    /// Migrations only move forward: each schema change is a new, named
    /// migration, and an applied migration is never edited.
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        // Permanent no op so the file exists with a migration history.
        migrator.registerMigration("v0_scaffold") { _ in }
        migrator.registerMigration("v1_core", migrate: createCoreTables)

        return migrator
    }

    // swiftlint:disable function_body_length
    /// The Slice 1 tables from spec 0002. The SQL is written out in full so it can never change by accident.
    private static func createCoreTables(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE learner (
                    id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36 AND id = lower(id)),
                    displayName TEXT,
                    createdAt DATETIME NOT NULL
                );

                CREATE TABLE course (
                    id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36 AND id = lower(id)),
                    learnerId TEXT NOT NULL REFERENCES learner(id) ON DELETE RESTRICT,
                    targetLanguage TEXT NOT NULL,
                    nativeLanguage TEXT NOT NULL,
                    createdAt DATETIME NOT NULL,
                    archivedAt DATETIME,
                    CHECK (targetLanguage <> nativeLanguage),
                    UNIQUE (learnerId, targetLanguage)
                );

                CREATE TABLE generation (
                    id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36 AND id = lower(id)),
                    courseId TEXT NOT NULL REFERENCES course(id) ON DELETE RESTRICT,
                    kind TEXT NOT NULL,
                    model TEXT,
                    promptVersion TEXT NOT NULL,
                    rawReply TEXT NOT NULL,
                    durationMs INTEGER NOT NULL CHECK (durationMs >= 0),
                    createdAt DATETIME NOT NULL
                );
                CREATE INDEX generation_on_courseId ON generation(courseId);

                CREATE TABLE lesson (
                    id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36 AND id = lower(id)),
                    courseId TEXT NOT NULL REFERENCES course(id) ON DELETE RESTRICT,
                    generationId TEXT REFERENCES generation(id) ON DELETE RESTRICT,
                    kind TEXT NOT NULL,
                    title TEXT NOT NULL,
                    topic TEXT NOT NULL,
                    explanation TEXT NOT NULL,
                    state TEXT NOT NULL CHECK (state IN ('ready', 'inProgress', 'completed')),
                    createdAt DATETIME NOT NULL,
                    startedAt DATETIME,
                    completedAt DATETIME,
                    archivedAt DATETIME,
                    CHECK ((state = 'ready') = (startedAt IS NULL)),
                    CHECK ((state = 'completed') = (completedAt IS NOT NULL))
                );
                CREATE INDEX lesson_on_courseId_createdAt ON lesson(courseId, createdAt);
                CREATE INDEX lesson_on_generationId ON lesson(generationId);

                CREATE TABLE exercise (
                    id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36 AND id = lower(id)),
                    lessonId TEXT NOT NULL REFERENCES lesson(id) ON DELETE RESTRICT,
                    position INTEGER NOT NULL,
                    kind TEXT NOT NULL,
                    prompt TEXT NOT NULL,
                    explanation TEXT,
                    UNIQUE (lessonId, position)
                );

                CREATE TABLE exercisePart (
                    id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36 AND id = lower(id)),
                    exerciseId TEXT NOT NULL REFERENCES exercise(id) ON DELETE RESTRICT,
                    sourcePosition INTEGER NOT NULL,
                    text TEXT NOT NULL,
                    displayPosition INTEGER,
                    isCorrect INTEGER CHECK (isCorrect IN (0, 1)),
                    correctPosition INTEGER,
                    matchKey TEXT,
                    UNIQUE (exerciseId, sourcePosition)
                );
                CREATE UNIQUE INDEX exercisePart_on_exerciseId_displayPosition
                    ON exercisePart(exerciseId, displayPosition) WHERE displayPosition IS NOT NULL;

                CREATE TABLE attempt (
                    id TEXT NOT NULL PRIMARY KEY CHECK (length(id) = 36 AND id = lower(id)),
                    exerciseId TEXT NOT NULL REFERENCES exercise(id) ON DELETE RESTRICT,
                    attemptNumber INTEGER NOT NULL CHECK (attemptNumber >= 1),
                    response TEXT NOT NULL,
                    grade TEXT NOT NULL CHECK (grade IN ('correct', 'partlyCorrect', 'wrong')),
                    feedback TEXT NOT NULL,
                    gradedBy TEXT NOT NULL CHECK (gradedBy IN ('app', 'claude')),
                    answeredAt DATETIME NOT NULL,
                    UNIQUE (exerciseId, attemptNumber)
                );
                """)
    }
    // swiftlint:enable function_body_length
}
