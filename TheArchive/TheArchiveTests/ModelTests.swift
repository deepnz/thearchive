import XCTest
import CloudKit
@testable import TheArchive

final class ModelTests: XCTestCase {

    func test_libraryItem_roundtrip_film() {
        let item = LibraryItem(
            id: UUID().uuidString,
            catalogID: "MV-0001",
            iTunesID: "12345",
            title: "Inception",
            year: 2010,
            type: .film,
            artworkURL: "https://example.com/art.jpg",
            genres: ["Sci-Fi"],
            watched: false,
            dateAdded: Date(timeIntervalSince1970: 0)
        )
        let record = item.toCKRecord()
        let restored = LibraryItem(record: record)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.title, "Inception")
        XCTAssertEqual(restored?.iTunesID, "12345")
        XCTAssertEqual(restored?.type, .film)
        XCTAssertEqual(restored?.genres, ["Sci-Fi"])
        XCTAssertEqual(restored?.watched, false)
    }

    func test_libraryItem_roundtrip_series() {
        let item = LibraryItem(
            id: UUID().uuidString,
            catalogID: "SV-0001",
            iTunesID: "67890",
            title: "Breaking Bad",
            year: 2008,
            type: .series,
            artworkURL: "",
            genres: [],
            watched: true,
            dateAdded: Date(timeIntervalSince1970: 0)
        )
        let record = item.toCKRecord()
        let restored = LibraryItem(record: record)
        XCTAssertEqual(restored?.type, .series)
        XCTAssertEqual(restored?.watched, true)
    }

    func test_watchlist_roundtrip() {
        let list = Watchlist(id: UUID().uuidString, name: "Weekend", itemIDs: ["111", "222"])
        let record = list.toCKRecord()
        let restored = Watchlist(record: record)
        XCTAssertEqual(restored?.name, "Weekend")
        XCTAssertEqual(restored?.itemIDs, ["111", "222"])
    }
}
