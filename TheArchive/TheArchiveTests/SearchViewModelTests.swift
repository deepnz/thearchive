import XCTest
@testable import TheArchive

final class SearchViewModelTests: XCTestCase {

    func test_isDuplicate_true() {
        let existing: Set<String> = ["111", "222"]
        XCTAssertTrue(SearchViewModel.isDuplicate(iTunesID: "111", existingIDs: existing))
    }

    func test_isDuplicate_false() {
        let existing: Set<String> = ["111", "222"]
        XCTAssertFalse(SearchViewModel.isDuplicate(iTunesID: "333", existingIDs: existing))
    }
}
