import Core
import Foundation
import GRDB

extension AppDatabase {
    /// Runs one write transaction with one rounded `now`, and maps every failure to a `StoreError`.
    func write<Value: Sendable>(
        _ work: @escaping @Sendable (Database, Date) throws -> Value
    ) async throws(StoreError) -> Value {
        do {
            return try await writer.write { db in try work(db, Date.now.roundedToMillisecond) }
        } catch {
            throw Self.mapError(error)
        }
    }

    /// Runs one read and maps every failure to a `StoreError`.
    func read<Value: Sendable>(_ work: @escaping @Sendable (Database) throws -> Value) async throws(StoreError) -> Value
    {
        do {
            return try await writer.read(work)
        } catch {
            throw Self.mapError(error)
        }
    }

    /// A stream of the current value and every later one. Finishes when `fetch` returns nil or on a database error.
    func liveStream<Value: Sendable>(
        fetch: @escaping @Sendable (Database) throws -> Value?
    ) -> AsyncStream<Value> {
        let writer = self.writer
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                do {
                    for try await value in ValueObservation.tracking(fetch).values(in: writer) {
                        guard let value else { break }
                        continuation.yield(value)
                    }
                } catch is CancellationError {
                    // The reader went away; nothing to report.
                } catch {
                    Log.store.error("Live read ended: \(String(describing: error), privacy: .public)")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The single place a database failure becomes a `StoreError`.
    static func mapError(_ error: any Error) -> StoreError {
        switch error {
        case let error as StoreError:
            return error
        case let error as ValidationError:
            return .invalid(error)
        case let error as DatabaseError:
            return mapDatabaseError(error)
        default:
            Log.store.error("Store call failed: \(String(describing: error), privacy: .private)")
            return .unavailable(reason: learnerReason)
        }
    }

    /// What the learner reads for a database failure. The engine's own text only goes to the log.
    private static let learnerReason = "Try again, and restart Verba if this keeps happening."

    private static func mapDatabaseError(_ error: DatabaseError) -> StoreError {
        if error.extendedResultCode == .SQLITE_CONSTRAINT_FOREIGNKEY {
            return .notFound
        }
        Log.store.error("Database call failed: \(error.message ?? "no message", privacy: .private)")
        return .unavailable(reason: learnerReason)
    }
}
