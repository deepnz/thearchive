import XCTest
@testable import TheArchive

final class CloudKitServiceTests: XCTestCase {

    func test_catalogID_format_film() {
        let id = CloudKitService.formatCatalogID(type: .film, count: 42)
        XCTAssertEqual(id, "MV-0042")
    }

    func test_catalogID_format_series() {
        let id = CloudKitService.formatCatalogID(type: .series, count: 7)
        XCTAssertEqual(id, "SV-0007")
    }

    func test_catalogID_fallback() {
        let id = CloudKitService.fallbackCatalogID(type: .film)
        XCTAssertEqual(id, "MV-????")
    }

    func test_pruneStaleIDs_removes_missing() {
        let watchlist = Watchlist(id: "w1", name: "Test", itemIDs: ["111", "222", "333"])
        let liveIDs: Set<String> = ["111", "333"]
        let pruned = CloudKitService.pruneStaleIDs(watchlist: watchlist, liveITunesIDs: liveIDs)
        XCTAssertEqual(pruned.itemIDs, ["111", "333"])
    }
}
