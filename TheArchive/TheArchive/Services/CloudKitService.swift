import CloudKit
import Combine
import Foundation

@MainActor
final class CloudKitService: ObservableObject {
    private let container: CKContainer
    private var db: CKDatabase { container.privateCloudDatabase }

    init(containerID: String = "iCloud.deepak-nalla.TheArchive") {
        container = CKContainer(identifier: containerID)
    }

    // MARK: - CatalogID helpers (static, testable)

    nonisolated static func formatCatalogID(type: MediaType, count: Int) -> String {
        let prefix = type == .film ? "MV" : "SV"
        return "\(prefix)-\(String(format: "%04d", count))"
    }

    nonisolated static func fallbackCatalogID(type: MediaType) -> String {
        type == .film ? "MV-????" : "SV-????"
    }

    nonisolated static func pruneStaleIDs(watchlist: Watchlist, liveITunesIDs: Set<String>) -> Watchlist {
        var updated = watchlist
        updated.itemIDs = watchlist.itemIDs.filter { liveITunesIDs.contains($0) }
        return updated
    }

    // MARK: - Library Items

    func fetchAllItems() async throws -> [LibraryItem] {
        let query = CKQuery(recordType: LibraryItem.recordType,
                            predicate: NSPredicate(value: true))
        var items: [LibraryItem] = []
        var cursor: CKQueryOperation.Cursor? = nil
        repeat {
            let (results, nextCursor) = cursor == nil
                ? try await db.records(matching: query)
                : try await db.records(continuingMatchFrom: cursor!)
            items += results.compactMap { _, result in try? result.get() }
                            .compactMap { LibraryItem(record: $0) }
            cursor = nextCursor
        } while cursor != nil
        return items
    }

    func saveItem(_ item: LibraryItem) async throws {
        let record = item.toCKRecord()
        try await db.save(record)
    }

    func deleteItem(_ item: LibraryItem) async throws {
        let recordID = CKRecord.ID(recordName: item.id)
        try await db.deleteRecord(withID: recordID)
    }

    func itemExists(iTunesID: String) async throws -> Bool {
        let pred = NSPredicate(format: "iTunesID == %@", iTunesID)
        let query = CKQuery(recordType: LibraryItem.recordType, predicate: pred)
        let (results, _) = try await db.records(matching: query, resultsLimit: 1)
        return !results.isEmpty
    }

    // MARK: - LibraryCounter

    private let counterRecordID = CKRecord.ID(recordName: "library-counter")

    func nextCatalogID(type: MediaType) async -> String {
        for attempt in 0..<3 {
            do {
                let counter = (try? await db.record(for: counterRecordID))
                    ?? CKRecord(recordType: "LibraryCounter", recordID: counterRecordID)

                let key = type == .film ? "filmCount" : "seriesCount"
                let current = counter[key] as? Int ?? 0
                let next = current + 1
                counter[key] = next

                let op = CKModifyRecordsOperation(recordsToSave: [counter])
                op.savePolicy = .ifServerRecordUnchanged
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    op.modifyRecordsResultBlock = { result in
                        switch result {
                        case .success: cont.resume()
                        case .failure(let e): cont.resume(throwing: e)
                        }
                    }
                    db.add(op)
                }
                return Self.formatCatalogID(type: type, count: next)
            } catch {
                // Conflict — wait with exponential backoff then retry
                let delay: UInt64 = [500_000_000, 1_000_000_000, 2_000_000_000][attempt]
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        return Self.fallbackCatalogID(type: type)
    }

    // MARK: - Watchlists

    func fetchAllWatchlists() async throws -> [Watchlist] {
        let query = CKQuery(recordType: Watchlist.recordType,
                            predicate: NSPredicate(value: true))
        var lists: [Watchlist] = []
        var cursor: CKQueryOperation.Cursor? = nil
        repeat {
            let (results, nextCursor) = cursor == nil
                ? try await db.records(matching: query)
                : try await db.records(continuingMatchFrom: cursor!)
            lists += results.compactMap { _, result in try? result.get() }
                            .compactMap { Watchlist(record: $0) }
            cursor = nextCursor
        } while cursor != nil
        return lists
    }

    func saveWatchlist(_ list: Watchlist) async throws {
        try await db.save(list.toCKRecord())
    }

    func deleteWatchlist(_ list: Watchlist) async throws {
        let recordID = CKRecord.ID(recordName: list.id)
        try await db.deleteRecord(withID: recordID)
    }
}
