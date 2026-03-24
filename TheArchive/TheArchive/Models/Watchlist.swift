import Foundation
import CloudKit

struct Watchlist: Identifiable, Hashable {
    let id: String       // CKRecord.ID recordName (UUID string)
    var name: String
    var itemIDs: [String]  // iTunesID values

    private enum Keys {
        static let name = "name"
        static let itemIDs = "itemIDs"
    }

    static let recordType = "Watchlist"

    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record[Keys.name] = name
        record[Keys.itemIDs] = itemIDs
        return record
    }

    init?(record: CKRecord) {
        guard let name = record[Keys.name] as? String else { return nil }
        self.id = record.recordID.recordName
        self.name = name
        self.itemIDs = record[Keys.itemIDs] as? [String] ?? []
    }

    init(id: String, name: String, itemIDs: [String]) {
        self.id = id
        self.name = name
        self.itemIDs = itemIDs
    }
}
