import XCTest
@testable import TheArchive

final class LibraryViewModelTests: XCTestCase {

    func makeItem(title: String, year: Int, type: MediaType, genres: [String] = [], watched: Bool = false) -> TheArchive.LibraryItem {
        TheArchive.LibraryItem(id: UUID().uuidString, catalogID: "MV-0001", iTunesID: UUID().uuidString,
                    title: title, year: year, type: type, artworkURL: "",
                    genres: genres, watched: watched, dateAdded: Date())
    }

    func test_filterByType_films() {
        let items = [
            makeItem(title: "Inception", year: 2010, type: MediaType.film),
            makeItem(title: "Breaking Bad", year: 2008, type: MediaType.series),
        ]
        let result = LibraryViewModel.filter(items, type: .film, genre: nil, query: "")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Inception")
    }

    func test_filterByGenre() {
        let items = [
            makeItem(title: "Inception", year: 2010, type: MediaType.film, genres: ["Sci-Fi"]),
            makeItem(title: "Goodfellas", year: 1990, type: MediaType.film, genres: ["Crime"]),
        ]
        let result = LibraryViewModel.filter(items, type: .all, genre: "Sci-Fi", query: "")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Inception")
    }

    func test_filterByQuery_caseInsensitive() {
        let items = [
            makeItem(title: "Inception", year: 2010, type: MediaType.film),
            makeItem(title: "Interstellar", year: 2014, type: MediaType.film),
        ]
        let result = LibraryViewModel.filter(items, type: .all, genre: nil, query: "inter")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Interstellar")
    }

    func test_sortAZ() {
        let items = [
            makeItem(title: "Zoolander", year: 2001, type: MediaType.film),
            makeItem(title: "Alien", year: 1979, type: MediaType.film),
        ]
        let sorted = LibraryViewModel.sort(items, by: .az)
        XCTAssertEqual(sorted[0].title, "Alien")
    }

    func test_genrePills_fromFilteredItems() {
        let items = [
            makeItem(title: "Inception", year: 2010, type: MediaType.film, genres: ["Sci-Fi", "Thriller"]),
            makeItem(title: "Goodfellas", year: 1990, type: MediaType.film, genres: ["Crime"]),
        ]
        let pills = LibraryViewModel.genrePills(from: items)
        XCTAssertTrue(pills.contains("Sci-Fi"))
        XCTAssertTrue(pills.contains("Thriller"))
        XCTAssertTrue(pills.contains("Crime"))
        XCTAssertEqual(pills, pills.sorted()) // alphabetical
    }
}
