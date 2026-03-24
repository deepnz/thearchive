# The Archive — tvOS App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native tvOS app ("The Archive") that lets users sign in with Apple, curate a personal film & TV library via iTunes Search, and open titles directly in the Apple TV app.

**Architecture:** No backend. SwiftUI tvOS app with Sign in with Apple for identity, CloudKit private database for library storage and sync, and iTunes Search API for metadata and artwork. All UI follows the archive.html visual design (gold/crimson on near-black, Playfair Display + Courier Prime).

**Tech Stack:** Swift 5.9+, SwiftUI, tvOS 17+, CloudKit, AuthenticationServices (Sign in with Apple), iTunes Search API (REST, no auth)

---

## File Structure

```
TheArchive/
├── TheArchiveApp.swift              # App entry point, TabView root
├── PrivacyInfo.xcprivacy            # App Store privacy manifest
│
├── Theme/
│   └── ArchiveTheme.swift           # Color tokens, font helpers, focus styles
│
├── Models/
│   ├── LibraryItem.swift            # LibraryItem struct + CKRecord mapping
│   ├── Watchlist.swift              # Watchlist struct + CKRecord mapping
│   └── iTunesResult.swift           # iTunes Search API response model
│
├── Services/
│   ├── AuthService.swift            # Sign in with Apple, credential state checks
│   ├── CloudKitService.swift        # All CloudKit reads/writes (LibraryItem, Watchlist, LibraryCounter)
│   └── iTunesService.swift          # iTunes Search API fetch + URL construction
│
├── ViewModels/
│   ├── LibraryViewModel.swift       # Library tab state: items, filters, search, sort
│   ├── SearchViewModel.swift        # Search tab state: query, results, add flow
│   └── WatchlistViewModel.swift     # Watchlists tab state: lists, CRUD
│
├── Views/
│   ├── Auth/
│   │   └── SignInView.swift         # Sign in with Apple screen
│   ├── Library/
│   │   ├── LibraryView.swift        # Library tab root: toolbar + grid
│   │   ├── PosterCardView.swift     # Individual poster card
│   │   ├── GenrePillsView.swift     # Horizontal genre filter pills row
│   │   └── DetailSheetView.swift   # Full-screen detail sheet
│   ├── Search/
│   │   └── SearchView.swift         # Search tab: input + results grid
│   └── Watchlists/
│       └── WatchlistsView.swift     # NavigationSplitView: sidebar + grid
│
└── Tests/
    ├── ModelTests.swift             # CKRecord mapping round-trips
    ├── iTunesServiceTests.swift     # URL building, response parsing
    ├── CloudKitServiceTests.swift   # Mocked CK operations
    ├── LibraryViewModelTests.swift  # Filter, sort, search logic
    └── SearchViewModelTests.swift   # Dedup, add flow logic
```

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `TheArchive.xcodeproj` (via Xcode)
- Create: `TheArchive/PrivacyInfo.xcprivacy`
- Modify: `TheArchive/Info.plist`

- [ ] **Step 1: Create the Xcode project**

  In Xcode: File → New → Project → tvOS → App
  - Product Name: `TheArchive`
  - Bundle ID: `com.yourname.TheArchive` ⚠️ Replace `yourname` with your real identifier everywhere it appears — also update the `containerID` in `CloudKitService.init` (Task 6) to match, or CloudKit calls will fail silently.
  - Interface: SwiftUI
  - Language: Swift
  - Minimum deployment: tvOS 17.0
  - Uncheck "Include Tests" (we'll add manually)

- [ ] **Step 2: Add capabilities**

  In Xcode → Target → Signing & Capabilities:
  - Add **Sign in with Apple**
  - Add **iCloud** → check **CloudKit** → add container `iCloud.com.yourname.TheArchive`

- [ ] **Step 3: Add font files to project**

  Download from Google Fonts (SIL Open Font License):
  - Playfair Display: Regular, Italic, Bold, Bold Italic (4 `.ttf` files)
  - Courier Prime: Regular, Bold (2 `.ttf` files)

  Drag all `.ttf` files into Xcode, check "Add to target: TheArchive".

- [ ] **Step 4: Declare fonts in Info.plist**

  Add `UIAppFonts` array to `Info.plist` with all 6 font filenames:
  ```xml
  <key>UIAppFonts</key>
  <array>
    <string>PlayfairDisplay-Regular.ttf</string>
    <string>PlayfairDisplay-Italic.ttf</string>
    <string>PlayfairDisplay-Bold.ttf</string>
    <string>PlayfairDisplay-BoldItalic.ttf</string>
    <string>CourierPrime-Regular.ttf</string>
    <string>CourierPrime-Bold.ttf</string>
  </array>
  ```

  Also add:
  ```xml
  <key>NSiCloudUsageDescription</key>
  <string>The Archive uses iCloud to sync your library across your devices.</string>
  ```

- [ ] **Step 5: Create PrivacyInfo.xcprivacy**

  File → New → File → Privacy Manifest. Declare:
  - `NSPrivacyAccessedAPITypes`: CloudKit (`com.apple.developer.icloud-container-identifiers`), UserDefaults (`NSPrivacyAccessedAPICategoryUserDefaults`)
  - `NSPrivacyCollectedDataTypes`: none (no data collected from users)
  - `NSPrivacyTracking`: `false`

- [ ] **Step 6: Add test target**

  File → New → Target → tvOS → Unit Testing Bundle
  - Name: `TheArchiveTests`
  - Ensure it links against `TheArchive`

- [ ] **Step 7: Commit**

  ```bash
  git add .
  git commit -m "chore: initial Xcode project setup with CloudKit, Sign in with Apple, fonts"
  ```

---

## Task 2: Theme System

**Files:**
- Create: `TheArchive/Theme/ArchiveTheme.swift`

- [ ] **Step 1: Write ArchiveTheme.swift**

  ```swift
  import SwiftUI

  enum ArchiveTheme {
      // MARK: - Colors
      static let background    = Color(hex: "#0a0806")
      static let surface       = Color(hex: "#110e0b")
      static let accent        = Color(hex: "#c8973a") // gold
      static let accent2       = Color(hex: "#8b2635") // crimson
      static let textPrimary   = Color(hex: "#e8dcc8")
      static let textMuted     = Color(hex: "#6b5d4a")
      static let border        = Color(hex: "#2a2218")

      // MARK: - Typography
      static func titleFont(size: CGFloat = 32) -> Font {
          .custom("PlayfairDisplay-BoldItalic", size: size)
      }
      static func bodyFont(size: CGFloat = 18) -> Font {
          .custom("CourierPrime-Regular", size: size)
      }
      static func monoFont(size: CGFloat = 14) -> Font {
          .custom("CourierPrime-Regular", size: size)
      }

      // MARK: - Poster gradient fallback
      // Deterministic gradient from title hash — matches archive.html system
      static func posterGradient(for title: String) -> LinearGradient {
          let gradients: [(Color, Color)] = [
              (Color(hex: "#1a2a3a"), Color(hex: "#0d1a2a")),
              (Color(hex: "#2a1a1a"), Color(hex: "#1a0d0d")),
              (Color(hex: "#1a2a1a"), Color(hex: "#0d1a0d")),
              (Color(hex: "#2a1a2a"), Color(hex: "#1a0d1a")),
              (Color(hex: "#2a2a1a"), Color(hex: "#1a1a0d")),
              (Color(hex: "#1a2a2a"), Color(hex: "#0d1a1a")),
              (Color(hex: "#231a2a"), Color(hex: "#130d1a")),
              (Color(hex: "#2a221a"), Color(hex: "#1a150d")),
          ]
          let index = abs(title.hashValue) % gradients.count
          return LinearGradient(
              colors: [gradients[index].0, gradients[index].1],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
          )
      }
  }

  // MARK: - Color hex init
  extension Color {
      init(hex: String) {
          let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
          var int: UInt64 = 0
          Scanner(string: hex).scanHexInt64(&int)
          let r = Double((int >> 16) & 0xFF) / 255
          let g = Double((int >> 8) & 0xFF) / 255
          let b = Double(int & 0xFF) / 255
          self.init(red: r, green: g, blue: b)
      }
  }
  ```

- [ ] **Step 2: Build to verify no compile errors**

  In Xcode: Cmd+B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

  ```bash
  git add TheArchive/Theme/ArchiveTheme.swift
  git commit -m "feat: add ArchiveTheme with color tokens, typography, and poster gradient"
  ```

---

## Task 3: Data Models

**Files:**
- Create: `TheArchive/Models/LibraryItem.swift`
- Create: `TheArchive/Models/Watchlist.swift`
- Create: `TheArchive/Models/iTunesResult.swift`
- Create: `TheArchiveTests/ModelTests.swift`

- [ ] **Step 1: Write the failing model tests**

  ```swift
  // TheArchiveTests/ModelTests.swift
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
  ```

- [ ] **Step 2: Run tests to verify they fail**

  In Xcode: Cmd+U. Expected: compile error — `LibraryItem`, `Watchlist` not defined.

- [ ] **Step 3: Write LibraryItem.swift**

  ```swift
  // TheArchive/Models/LibraryItem.swift
  import Foundation
  import CloudKit

  enum MediaType: String {
      case film = "film"
      case series = "series"
  }

  struct LibraryItem: Identifiable, Hashable {
      let id: String            // CKRecord.ID recordName (UUID string)
      var catalogID: String     // display-only: MV-XXXX or SV-XXXX
      var iTunesID: String      // dedup + deep link key
      var title: String
      var year: Int
      var type: MediaType
      var artworkURL: String
      var genres: [String]
      var watched: Bool
      var dateAdded: Date

      // MARK: - CKRecord keys
      private enum Keys {
          static let catalogID = "catalogID"
          static let iTunesID = "iTunesID"
          static let title = "title"
          static let year = "year"
          static let type = "type"
          static let artworkURL = "artworkURL"
          static let genres = "genres"
          static let watched = "watched"
          static let dateAdded = "dateAdded"
      }

      static let recordType = "LibraryItem"

      func toCKRecord() -> CKRecord {
          let recordID = CKRecord.ID(recordName: id)
          let record = CKRecord(recordType: Self.recordType, recordID: recordID)
          record[Keys.catalogID] = catalogID
          record[Keys.iTunesID] = iTunesID
          record[Keys.title] = title
          record[Keys.year] = year
          record[Keys.type] = type.rawValue
          record[Keys.artworkURL] = artworkURL
          record[Keys.genres] = genres
          record[Keys.watched] = watched ? 1 : 0
          record[Keys.dateAdded] = dateAdded
          return record
      }

      init?(record: CKRecord) {
          guard
              let catalogID = record[Keys.catalogID] as? String,
              let iTunesID = record[Keys.iTunesID] as? String,
              let title = record[Keys.title] as? String,
              let year = record[Keys.year] as? Int,
              let typeRaw = record[Keys.type] as? String,
              let type = MediaType(rawValue: typeRaw),
              let artworkURL = record[Keys.artworkURL] as? String,
              let watchedInt = record[Keys.watched] as? Int,
              let dateAdded = record[Keys.dateAdded] as? Date
          else { return nil }

          self.id = record.recordID.recordName
          self.catalogID = catalogID
          self.iTunesID = iTunesID
          self.title = title
          self.year = year
          self.type = type
          self.artworkURL = artworkURL
          self.genres = record[Keys.genres] as? [String] ?? []
          self.watched = watchedInt == 1
          self.dateAdded = dateAdded
      }

      init(id: String, catalogID: String, iTunesID: String, title: String, year: Int,
           type: MediaType, artworkURL: String, genres: [String], watched: Bool, dateAdded: Date) {
          self.id = id
          self.catalogID = catalogID
          self.iTunesID = iTunesID
          self.title = title
          self.year = year
          self.type = type
          self.artworkURL = artworkURL
          self.genres = genres
          self.watched = watched
          self.dateAdded = dateAdded
      }
  }
  ```

- [ ] **Step 4: Write Watchlist.swift**

  ```swift
  // TheArchive/Models/Watchlist.swift
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
  ```

- [ ] **Step 5: Write iTunesResult.swift**

  ```swift
  // TheArchive/Models/iTunesResult.swift
  import Foundation

  struct iTunesSearchResponse: Decodable {
      let results: [iTunesResult]
  }

  struct iTunesResult: Identifiable, Decodable {
      let id: String           // derived from trackId or collectionId
      let title: String
      let year: Int
      let type: MediaType
      let artworkURL: String   // 600x900bb substituted

      private enum CodingKeys: String, CodingKey {
          case trackId, collectionId, trackName, collectionName
          case releaseDate, wrapperType, kind
          case artworkUrl100
      }

      init(from decoder: Decoder) throws {
          let c = try decoder.container(keyedBy: CodingKeys.self)

          let wrapperType = try c.decodeIfPresent(String.self, forKey: .wrapperType) ?? ""
          let kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""

          // Determine type
          if kind == "feature-movie" {
              type = .film
              let trackId = try c.decode(Int.self, forKey: .trackId)
              id = "\(trackId)"
              title = try c.decode(String.self, forKey: .trackName)
          } else {
              // TV collection
              type = .series
              let collectionId = try c.decode(Int.self, forKey: .collectionId)
              id = "\(collectionId)"
              title = try c.decodeIfPresent(String.self, forKey: .collectionName)
                      ?? (try c.decode(String.self, forKey: .trackName))
          }

          // Year from releaseDate
          let releaseDateString = try c.decodeIfPresent(String.self, forKey: .releaseDate) ?? ""
          let formatter = ISO8601DateFormatter()
          formatter.formatOptions = [.withInternetDateTime]
          let date = formatter.date(from: releaseDateString)
          let calendar = Calendar.current
          year = date.map { calendar.component(.year, from: $0) } ?? 0

          // Artwork — substitute size token
          let rawArtwork = try c.decodeIfPresent(String.self, forKey: .artworkUrl100) ?? ""
          artworkURL = rawArtwork
              .replacingOccurrences(of: "100x100bb", with: "600x900bb")
              .replacingOccurrences(of: "100x100", with: "600x900")
      }
  }
  ```

- [ ] **Step 6: Run tests to verify they pass**

  Cmd+U. Expected: all 3 model tests pass.

- [ ] **Step 7: Commit**

  ```bash
  git add TheArchive/Models/ TheArchiveTests/ModelTests.swift
  git commit -m "feat: add LibraryItem, Watchlist, iTunesResult models with CKRecord mapping"
  ```

---

## Task 4: iTunes Service

**Files:**
- Create: `TheArchive/Services/iTunesService.swift`
- Create: `TheArchiveTests/iTunesServiceTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // TheArchiveTests/iTunesServiceTests.swift
  import XCTest
  @testable import TheArchive

  final class iTunesServiceTests: XCTestCase {

      func test_searchURL_films() {
          let url = iTunesService.searchURL(query: "Inception")
          XCTAssertNotNil(url)
          let str = url!.absoluteString
          XCTAssertTrue(str.contains("term=Inception"))
          XCTAssertTrue(str.contains("media=movie"))
      }

      func test_searchURL_encodes_spaces() {
          let url = iTunesService.searchURL(query: "The Dark Knight")
          XCTAssertNotNil(url)
          XCTAssertFalse(url!.absoluteString.contains(" "))
      }

      func test_parseResponse_decodesFilm() throws {
          let json = """
          {"results": [{
            "wrapperType": "track",
            "kind": "feature-movie",
            "trackId": 999,
            "trackName": "Inception",
            "releaseDate": "2010-07-16T07:00:00Z",
            "artworkUrl100": "https://example.com/100x100bb.jpg"
          }]}
          """.data(using: .utf8)!

          let response = try JSONDecoder().decode(iTunesSearchResponse.self, from: json)
          XCTAssertEqual(response.results.count, 1)
          XCTAssertEqual(response.results[0].title, "Inception")
          XCTAssertEqual(response.results[0].id, "999")
          XCTAssertEqual(response.results[0].type, .film)
          XCTAssertEqual(response.results[0].year, 2010)
          XCTAssertTrue(response.results[0].artworkURL.contains("600x900bb"))
      }
  }
  ```

- [ ] **Step 2: Run to verify failure**

  Cmd+U. Expected: compile error — `iTunesService` not defined.

- [ ] **Step 3: Write iTunesService.swift**

  ```swift
  // TheArchive/Services/iTunesService.swift
  import Foundation

  enum iTunesService {
      private static let base = "https://itunes.apple.com/search"

      static func searchURL(query: String) -> URL? {
          var components = URLComponents(string: base)
          // media=all with entity=movie,tvSeason returns both films and TV collections.
          // Do NOT use media=movie here — it suppresses TV results.
          components?.queryItems = [
              URLQueryItem(name: "term", value: query),
              URLQueryItem(name: "media", value: "all"),
              URLQueryItem(name: "entity", value: "movie,tvSeason"),
              URLQueryItem(name: "limit", value: "25"),
          ]
          return components?.url
      }

      static func search(query: String) async throws -> [iTunesResult] {
          guard let url = searchURL(query: query) else {
              throw URLError(.badURL)
          }
          let (data, _) = try await URLSession.shared.data(from: url)
          let response = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)

          // Deduplicate by id (iTunes may return both movie and tvSeason for same title)
          var seen = Set<String>()
          return response.results.filter { seen.insert($0.id).inserted }
      }
  }
  ```

- [ ] **Step 4: Run tests to verify they pass**

  Cmd+U. Expected: all 3 iTunes service tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add TheArchive/Services/iTunesService.swift TheArchiveTests/iTunesServiceTests.swift
  git commit -m "feat: add iTunesService with search URL builder and JSON decoding"
  ```

---

## Task 5: Auth Service

**Files:**
- Create: `TheArchive/Services/AuthService.swift`

- [ ] **Step 1: Write AuthService.swift**

  ```swift
  // TheArchive/Services/AuthService.swift
  import AuthenticationServices
  import Combine

  @MainActor
  final class AuthService: NSObject, ObservableObject {
      @Published var isSignedIn: Bool = false
      @Published var userID: String? = nil

      private let userIDKey = "archive.userID"

      override init() {
          super.init()
          userID = UserDefaults.standard.string(forKey: userIDKey)
          isSignedIn = userID != nil
      }

      // Called on each app foreground — checks credential is still valid
      func checkCredentialState() async {
          guard let userID else {
              isSignedIn = false
              return
          }
          let provider = ASAuthorizationAppleIDProvider()
          do {
              let state = try await provider.credentialState(forUserID: userID)
              await MainActor.run {
                  isSignedIn = (state == .authorized)
                  if !isSignedIn { clearSession() }
              }
          } catch {
              await MainActor.run { isSignedIn = false }
          }
      }

      func handleAuthorization(result: Result<ASAuthorization, Error>) {
          switch result {
          case .success(let auth):
              guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
              UserDefaults.standard.set(credential.user, forKey: userIDKey)
              userID = credential.user
              isSignedIn = true
          case .failure:
              isSignedIn = false
          }
      }

      func signOut() {
          clearSession()
      }

      private func clearSession() {
          UserDefaults.standard.removeObject(forKey: userIDKey)
          userID = nil
          isSignedIn = false
      }
  }
  ```

- [ ] **Step 2: Build to verify no compile errors**

  Cmd+B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

  ```bash
  git add TheArchive/Services/AuthService.swift
  git commit -m "feat: add AuthService for Sign in with Apple credential management"
  ```

---

## Task 6: CloudKit Service

**Files:**
- Create: `TheArchive/Services/CloudKitService.swift`
- Create: `TheArchiveTests/CloudKitServiceTests.swift`

- [ ] **Step 1: Write failing tests for catalogID generation**

  ```swift
  // TheArchiveTests/CloudKitServiceTests.swift
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
  ```

- [ ] **Step 2: Run to verify failure**

  Cmd+U. Expected: compile error.

- [ ] **Step 3: Write CloudKitService.swift**

  ```swift
  // TheArchive/Services/CloudKitService.swift
  import CloudKit
  import Foundation

  @MainActor
  final class CloudKitService: ObservableObject {
      private let container: CKContainer
      private var db: CKDatabase { container.privateCloudDatabase }

      init(containerID: String = "iCloud.com.yourname.TheArchive") {
          container = CKContainer(identifier: containerID)
      }

      // MARK: - CatalogID helpers (static, testable)

      static func formatCatalogID(type: MediaType, count: Int) -> String {
          let prefix = type == .film ? "MV" : "SV"
          return "\(prefix)-\(String(format: "%04d", count))"
      }

      static func fallbackCatalogID(type: MediaType) -> String {
          type == .film ? "MV-????" : "SV-????"
      }

      static func pruneStaleIDs(watchlist: Watchlist, liveITunesIDs: Set<String>) -> Watchlist {
          var updated = watchlist
          updated.itemIDs = watchlist.itemIDs.filter { liveITunesIDs.contains($0) }
          return updated
      }

      // MARK: - Library Items

      func fetchAllItems() async throws -> [LibraryItem] {
          let query = CKQuery(recordType: LibraryItem.recordType,
                              predicate: NSPredicate(value: true))
          let (results, _) = try await db.records(matching: query)
          return results.compactMap { _, result in
              try? result.get()
          }.compactMap { LibraryItem(record: $0) }
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
          let (results, _) = try await db.records(matching: query)
          return results.compactMap { _, result in
              try? result.get()
          }.compactMap { Watchlist(record: $0) }
      }

      func saveWatchlist(_ list: Watchlist) async throws {
          try await db.save(list.toCKRecord())
      }

      func deleteWatchlist(_ list: Watchlist) async throws {
          let recordID = CKRecord.ID(recordName: list.id)
          try await db.deleteRecord(withID: recordID)
      }
  }
  ```

- [ ] **Step 4: Run tests to verify they pass**

  Cmd+U. Expected: all 4 CloudKit service tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add TheArchive/Services/CloudKitService.swift TheArchiveTests/CloudKitServiceTests.swift
  git commit -m "feat: add CloudKitService with CRUD, catalogID generation, and stale pruning"
  ```

---

## Task 7: ViewModels

**Files:**
- Create: `TheArchive/ViewModels/LibraryViewModel.swift`
- Create: `TheArchive/ViewModels/SearchViewModel.swift`
- Create: `TheArchive/ViewModels/WatchlistViewModel.swift`
- Create: `TheArchiveTests/LibraryViewModelTests.swift`
- Create: `TheArchiveTests/SearchViewModelTests.swift`

- [ ] **Step 1: Write failing ViewModel tests**

  ```swift
  // TheArchiveTests/LibraryViewModelTests.swift
  import XCTest
  @testable import TheArchive

  final class LibraryViewModelTests: XCTestCase {

      func makeItem(title: String, year: Int, type: MediaType, genres: [String] = [], watched: Bool = false) -> LibraryItem {
          LibraryItem(id: UUID().uuidString, catalogID: "MV-0001", iTunesID: UUID().uuidString,
                      title: title, year: year, type: type, artworkURL: "",
                      genres: genres, watched: watched, dateAdded: Date())
      }

      func test_filterByType_films() {
          let items = [
              makeItem(title: "Inception", year: 2010, type: .film),
              makeItem(title: "Breaking Bad", year: 2008, type: .series),
          ]
          let result = LibraryViewModel.filter(items, type: .film, genre: nil, query: "")
          XCTAssertEqual(result.count, 1)
          XCTAssertEqual(result[0].title, "Inception")
      }

      func test_filterByGenre() {
          let items = [
              makeItem(title: "Inception", year: 2010, type: .film, genres: ["Sci-Fi"]),
              makeItem(title: "Goodfellas", year: 1990, type: .film, genres: ["Crime"]),
          ]
          let result = LibraryViewModel.filter(items, type: .all, genre: "Sci-Fi", query: "")
          XCTAssertEqual(result.count, 1)
          XCTAssertEqual(result[0].title, "Inception")
      }

      func test_filterByQuery_caseInsensitive() {
          let items = [
              makeItem(title: "Inception", year: 2010, type: .film),
              makeItem(title: "Interstellar", year: 2014, type: .film),
          ]
          let result = LibraryViewModel.filter(items, type: .all, genre: nil, query: "inter")
          XCTAssertEqual(result.count, 1)
          XCTAssertEqual(result[0].title, "Interstellar")
      }

      func test_sortAZ() {
          let items = [
              makeItem(title: "Zoolander", year: 2001, type: .film),
              makeItem(title: "Alien", year: 1979, type: .film),
          ]
          let sorted = LibraryViewModel.sort(items, by: .az)
          XCTAssertEqual(sorted[0].title, "Alien")
      }

      func test_genrePills_fromFilteredItems() {
          let items = [
              makeItem(title: "Inception", year: 2010, type: .film, genres: ["Sci-Fi", "Thriller"]),
              makeItem(title: "Goodfellas", year: 1990, type: .film, genres: ["Crime"]),
          ]
          let pills = LibraryViewModel.genrePills(from: items)
          XCTAssertTrue(pills.contains("Sci-Fi"))
          XCTAssertTrue(pills.contains("Thriller"))
          XCTAssertTrue(pills.contains("Crime"))
          XCTAssertEqual(pills, pills.sorted()) // alphabetical
      }
  }

  // TheArchiveTests/SearchViewModelTests.swift
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
  ```

- [ ] **Step 2: Run to verify failure**

  Cmd+U. Expected: compile errors.

- [ ] **Step 3: Write LibraryViewModel.swift**

  ```swift
  // TheArchive/ViewModels/LibraryViewModel.swift
  import Foundation
  import Combine

  enum TypeFilter { case all, film, series }
  enum SortOrder { case az, za, yearNewest, yearOldest, newestAdded }

  @MainActor
  final class LibraryViewModel: ObservableObject {
      @Published var items: [LibraryItem] = []
      @Published var typeFilter: TypeFilter = .all
      @Published var selectedGenre: String? = nil
      @Published var searchQuery: String = ""
      @Published var sortOrder: SortOrder = .az
      @Published var isLoading: Bool = false
      @Published var isOffline: Bool = false

      var filteredItems: [LibraryItem] {
          let filtered = Self.filter(items, type: typeFilter, genre: selectedGenre, query: searchQuery)
          return Self.sort(filtered, by: sortOrder)
      }

      var genrePills: [String] {
          let baseItems = Self.filter(items, type: typeFilter, genre: nil, query: "")
          return Self.genrePills(from: baseItems)
      }

      // MARK: - Static pure functions (testable without @MainActor)

      static func filter(_ items: [LibraryItem], type: TypeFilter, genre: String?, query: String) -> [LibraryItem] {
          items.filter { item in
              let matchesType: Bool = {
                  switch type {
                  case .all: return true
                  case .film: return item.type == .film
                  case .series: return item.type == .series
                  }
              }()
              let matchesGenre = genre == nil || item.genres.contains(genre!)
              let matchesQuery = query.isEmpty || item.title.localizedCaseInsensitiveContains(query)
              return matchesType && matchesGenre && matchesQuery
          }
      }

      static func sort(_ items: [LibraryItem], by order: SortOrder) -> [LibraryItem] {
          switch order {
          case .az:          return items.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
          case .za:          return items.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
          case .yearNewest:  return items.sorted { $0.year > $1.year }
          case .yearOldest:  return items.sorted { $0.year < $1.year }
          case .newestAdded: return items.sorted { $0.dateAdded > $1.dateAdded }
          }
      }

      static func genrePills(from items: [LibraryItem]) -> [String] {
          Array(Set(items.flatMap(\.genres))).sorted()
      }
  }
  ```

- [ ] **Step 4: Write SearchViewModel.swift**

  ```swift
  // TheArchive/ViewModels/SearchViewModel.swift
  import Foundation

  @MainActor
  final class SearchViewModel: ObservableObject {
      @Published var query: String = ""
      @Published var results: [iTunesResult] = []
      @Published var isSearching: Bool = false
      @Published var errorMessage: String? = nil

      static func isDuplicate(iTunesID: String, existingIDs: Set<String>) -> Bool {
          existingIDs.contains(iTunesID)
      }

      func search(existingIDs: Set<String>) async {
          guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
          isSearching = true
          errorMessage = nil
          do {
              let raw = try await iTunesService.search(query: query)
              results = raw
              if results.isEmpty { errorMessage = "No results for \"\(query)\"" }
          } catch let error as URLError where error.code == .notConnectedToInternet {
              errorMessage = "No connection — check your network and try again"
              results = []
          } catch {
              errorMessage = "Search unavailable — try again in a moment"
              results = []
          }
          isSearching = false
      }
  }
  ```

- [ ] **Step 5: Write WatchlistViewModel.swift**

  ```swift
  // TheArchive/ViewModels/WatchlistViewModel.swift
  import Foundation

  @MainActor
  final class WatchlistViewModel: ObservableObject {
      @Published var watchlists: [Watchlist] = []
      @Published var selectedListID: String? = nil

      var selectedList: Watchlist? {
          watchlists.first { $0.id == selectedListID }
      }

      func pruneStale(liveITunesIDs: Set<String>, using ck: CloudKitService) async {
          for list in watchlists {
              let pruned = CloudKitService.pruneStaleIDs(watchlist: list, liveITunesIDs: liveITunesIDs)
              if pruned.itemIDs != list.itemIDs {
                  if let idx = watchlists.firstIndex(where: { $0.id == list.id }) {
                      watchlists[idx] = pruned
                  }
                  try? await ck.saveWatchlist(pruned)
              }
          }
      }
  }
  ```

- [ ] **Step 6: Run tests to verify they pass**

  Cmd+U. Expected: all viewmodel tests pass.

- [ ] **Step 7: Commit**

  ```bash
  git add TheArchive/ViewModels/ TheArchiveTests/LibraryViewModelTests.swift TheArchiveTests/SearchViewModelTests.swift
  git commit -m "feat: add LibraryViewModel, SearchViewModel, WatchlistViewModel with pure filter/sort logic"
  ```

---

## Task 8: Sign In View

**Files:**
- Create: `TheArchive/Views/Auth/SignInView.swift`

- [ ] **Step 1: Write SignInView.swift**

  ```swift
  // TheArchive/Views/Auth/SignInView.swift
  import SwiftUI
  import AuthenticationServices

  struct SignInView: View {
      @EnvironmentObject var auth: AuthService

      var body: some View {
          ZStack {
              ArchiveTheme.background.ignoresSafeArea()

              VStack(spacing: 40) {
                  // Logo
                  VStack(spacing: 8) {
                      Text("The Archive")
                          .font(ArchiveTheme.titleFont(size: 56))
                          .foregroundColor(ArchiveTheme.accent)
                      Text("YOUR PERSONAL COLLECTION")
                          .font(ArchiveTheme.monoFont(size: 16))
                          .foregroundColor(ArchiveTheme.textMuted)
                          .kerning(4)
                  }

                  // Sign in button
                  SignInWithAppleButton(.signIn) { request in
                      request.requestedScopes = [.fullName]
                  } onCompletion: { result in
                      auth.handleAuthorization(result: result)
                  }
                  .frame(width: 400, height: 64)
                  .signInWithAppleButtonStyle(.white)
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build and verify**

  Cmd+B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

  ```bash
  git add TheArchive/Views/Auth/SignInView.swift
  git commit -m "feat: add SignInView with Sign in with Apple button"
  ```

---

## Task 9: Poster Card & Genre Pills

**Files:**
- Create: `TheArchive/Views/Library/PosterCardView.swift`
- Create: `TheArchive/Views/Library/GenrePillsView.swift`

- [ ] **Step 1: Write PosterCardView.swift**

  ```swift
  // TheArchive/Views/Library/PosterCardView.swift
  import SwiftUI

  struct PosterCardView: View {
      let item: LibraryItem
      @State private var artworkImage: Image? = nil

      var body: some View {
          VStack(alignment: .leading, spacing: 0) {
              // Poster
              ZStack(alignment: .bottomLeading) {
                  // Background: artwork or gradient fallback
                  Group {
                      if let img = artworkImage {
                          img.resizable().scaledToFill()
                      } else {
                          ArchiveTheme.posterGradient(for: item.title)
                      }
                  }
                  .frame(width: 220, height: 330)
                  .clipped()

                  // Catalog badge
                  Text(item.catalogID)
                      .font(ArchiveTheme.monoFont(size: 11))
                      .foregroundColor(ArchiveTheme.textMuted)
                      .padding(6)
              }
              .frame(width: 220, height: 330)
              .cornerRadius(6)
              .overlay(
                  RoundedRectangle(cornerRadius: 6)
                      .stroke(ArchiveTheme.border, lineWidth: 1)
              )

              // Title + meta
              VStack(alignment: .leading, spacing: 4) {
                  Text(item.title)
                      .font(ArchiveTheme.bodyFont(size: 16))
                      .foregroundColor(ArchiveTheme.textPrimary)
                      .lineLimit(2)
                  Text(item.type == .film ? "\(item.year) · FILM" : "SERIES · \(item.year)")
                      .font(ArchiveTheme.monoFont(size: 12))
                      .foregroundColor(ArchiveTheme.textMuted)
              }
              .padding(.top, 8)
              .frame(width: 220, alignment: .leading)
          }
          .accessibilityLabel("\(item.type == .film ? "Film" : "Series"): \(item.title), \(item.year)")
          .task { await loadArtwork() }
      }

      private func loadArtwork() async {
          guard !item.artworkURL.isEmpty,
                let url = URL(string: item.artworkURL) else { return }
          do {
              let (data, _) = try await URLSession.shared.data(from: url)
              if let ui = UIImage(data: data) {
                  artworkImage = Image(uiImage: ui)
              }
          } catch { /* gradient fallback stays */ }
      }
  }
  ```

- [ ] **Step 2: Write GenrePillsView.swift**

  ```swift
  // TheArchive/Views/Library/GenrePillsView.swift
  import SwiftUI

  struct GenrePillsView: View {
      let genres: [String]
      @Binding var selected: String?

      var body: some View {
          ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 10) {
                  pill(label: "All Genres", value: nil)
                  ForEach(genres, id: \.self) { genre in
                      pill(label: genre, value: genre)
                  }
              }
              .padding(.horizontal, 40)
          }
      }

      @ViewBuilder
      private func pill(label: String, value: String?) -> some View {
          let isActive = selected == value
          Button(label) { selected = value }
              .font(ArchiveTheme.monoFont(size: 14))
              .foregroundColor(isActive ? ArchiveTheme.accent : ArchiveTheme.textMuted)
              .padding(.horizontal, 14)
              .padding(.vertical, 6)
              .background(
                  RoundedRectangle(cornerRadius: 3)
                      .stroke(isActive ? ArchiveTheme.accent.opacity(0.6) : ArchiveTheme.border, lineWidth: 1)
                      .background(isActive ? ArchiveTheme.accent.opacity(0.1) : Color.clear)
              )
              .accessibilityAddTraits(isActive ? .isSelected : [])
      }
  }
  ```

- [ ] **Step 3: Build to verify**

  Cmd+B. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

  ```bash
  git add TheArchive/Views/Library/PosterCardView.swift TheArchive/Views/Library/GenrePillsView.swift
  git commit -m "feat: add PosterCardView with artwork lazy-load and GenrePillsView"
  ```

---

## Task 10: Library View

**Files:**
- Create: `TheArchive/Views/Library/LibraryView.swift`

- [ ] **Step 1: Write LibraryView.swift**

  ```swift
  // TheArchive/Views/Library/LibraryView.swift
  import SwiftUI

  struct LibraryView: View {
      @EnvironmentObject var libraryVM: LibraryViewModel
      @EnvironmentObject var auth: AuthService
      @State private var showSignOutConfirm = false

      private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

      var body: some View {
          NavigationStack {
              ZStack(alignment: .top) {
                  ArchiveTheme.background.ignoresSafeArea()

                  VStack(spacing: 0) {
                      // Toolbar
                      toolbar

                      // Genre pills
                      GenrePillsView(genres: libraryVM.genrePills,
                                     selected: $libraryVM.selectedGenre)
                          .padding(.vertical, 10)

                      // Stats bar
                      statsBar

                      // Offline banner
                      if libraryVM.isOffline {
                          offlineBanner
                      }

                      // Grid
                      if libraryVM.isLoading {
                          Spacer()
                          ProgressView()
                              .progressViewStyle(.circular)
                              .tint(ArchiveTheme.accent)
                          Spacer()
                      } else if libraryVM.filteredItems.isEmpty {
                          emptyState
                      } else {
                          ScrollView {
                              LazyVGrid(columns: columns, spacing: 24) {
                                  ForEach(libraryVM.filteredItems) { item in
                                      NavigationLink(value: item) {
                                          PosterCardView(item: item)
                                      }
                                      .buttonStyle(.plain)
                                  }
                              }
                              .padding(40)
                          }
                      }
                  }
              }
              .navigationDestination(for: LibraryItem.self) { item in
                  DetailSheetView(item: item)
              }
          }
          .alert("Sign Out", isPresented: $showSignOutConfirm) {
              Button("Sign Out", role: .destructive) { auth.signOut() }
              Button("Cancel", role: .cancel) {}
          } message: {
              Text("Are you sure you want to sign out?")
          }
      }

      // MARK: - Subviews

      private var toolbar: some View {
          HStack(spacing: 20) {
              // Type segmented control
              Picker("Type", selection: $libraryVM.typeFilter) {
                  Text("All").tag(TypeFilter.all)
                  Text("Films").tag(TypeFilter.film)
                  Text("Series").tag(TypeFilter.series)
              }
              .pickerStyle(.segmented)
              .frame(width: 320)

              Spacer()

              // Sort
              Menu {
                  Button("A–Z") { libraryVM.sortOrder = .az }
                  Button("Z–A") { libraryVM.sortOrder = .za }
                  Button("Year: Newest") { libraryVM.sortOrder = .yearNewest }
                  Button("Year: Oldest") { libraryVM.sortOrder = .yearOldest }
                  Button("Newest Added") { libraryVM.sortOrder = .newestAdded }
              } label: {
                  Label("Sort", systemImage: "arrow.up.arrow.down")
                      .font(ArchiveTheme.monoFont(size: 14))
                      .foregroundColor(ArchiveTheme.textMuted)
              }

              // Account
              Button {
                  showSignOutConfirm = true
              } label: {
                  Image(systemName: "person.circle")
                      .font(.system(size: 24))
                      .foregroundColor(ArchiveTheme.textMuted)
              }
              .accessibilityLabel("Account")
          }
          .padding(.horizontal, 40)
          .padding(.vertical, 16)
      }

      private var statsBar: some View {
          HStack(spacing: 24) {
              statItem(value: "\(libraryVM.filteredItems.filter { $0.type == .film }.count)", label: "FILMS")
              statItem(value: "\(libraryVM.filteredItems.filter { $0.type == .series }.count)", label: "SERIES")
              statItem(value: "\(libraryVM.filteredItems.count)", label: "TOTAL")
          }
          .padding(.horizontal, 40)
          .padding(.vertical, 8)
      }

      private func statItem(value: String, label: String) -> some View {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
              Text(value)
                  .font(ArchiveTheme.monoFont(size: 18).weight(.bold))
                  .foregroundColor(ArchiveTheme.accent)
              Text(label)
                  .font(ArchiveTheme.monoFont(size: 12))
                  .foregroundColor(ArchiveTheme.textMuted)
                  .kerning(2)
          }
      }

      private var offlineBanner: some View {
          HStack {
              Image(systemName: "wifi.slash")
              Text("Offline — changes will sync when connected")
                  .font(ArchiveTheme.monoFont(size: 13))
          }
          .foregroundColor(ArchiveTheme.textMuted)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(ArchiveTheme.surface)
          .overlay(Rectangle().frame(height: 1).foregroundColor(ArchiveTheme.border), alignment: .bottom)
      }

      private var emptyState: some View {
          VStack(spacing: 16) {
              Spacer()
              Text("Nothing here yet")
                  .font(ArchiveTheme.titleFont(size: 32))
                  .foregroundColor(ArchiveTheme.textMuted)
              Text("Head to Search to add your first title.")
                  .font(ArchiveTheme.monoFont(size: 18))
                  .foregroundColor(ArchiveTheme.textMuted)
              Spacer()
          }
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  Cmd+B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

  ```bash
  git add TheArchive/Views/Library/LibraryView.swift
  git commit -m "feat: add LibraryView with poster grid, toolbar, stats bar, offline banner"
  ```

---

## Task 11: Detail Sheet View

**Files:**
- Create: `TheArchive/Views/Library/DetailSheetView.swift`

- [ ] **Step 1: Write DetailSheetView.swift**

  ```swift
  // TheArchive/Views/Library/DetailSheetView.swift
  import SwiftUI

  private let predefinedGenres = [
      "Action","Adventure","Animation","Biography","Comedy","Crime",
      "Documentary","Drama","Fantasy","Horror","Mystery","Romance",
      "Sci-Fi","Thriller","War","Western"
  ]

  struct DetailSheetView: View {
      let item: LibraryItem
      @EnvironmentObject var libraryVM: LibraryViewModel
      @EnvironmentObject var watchlistVM: WatchlistViewModel
      @EnvironmentObject var ck: CloudKitService
      @Environment(\.dismiss) var dismiss

      @State private var currentItem: LibraryItem
      @State private var showRemoveConfirm = false
      @State private var showOpenError = false
      @State private var customGenreInput = ""

      init(item: LibraryItem) {
          self.item = item
          self._currentItem = State(initialValue: item)
      }

      var body: some View {
          ZStack {
              ArchiveTheme.background.ignoresSafeArea()

              HStack(alignment: .top, spacing: 60) {
                  // Poster
                  PosterCardView(item: currentItem)

                  // Details
                  ScrollView {
                      VStack(alignment: .leading, spacing: 24) {
                          // Title + meta
                          VStack(alignment: .leading, spacing: 6) {
                              Text(currentItem.title)
                                  .font(ArchiveTheme.titleFont(size: 42))
                                  .foregroundColor(ArchiveTheme.textPrimary)
                              Text("\(currentItem.year) · \(currentItem.type == .film ? "Motion Picture" : "Television Series")")
                                  .font(ArchiveTheme.monoFont(size: 16))
                                  .foregroundColor(ArchiveTheme.textMuted)
                              Text(currentItem.catalogID)
                                  .font(ArchiveTheme.monoFont(size: 13))
                                  .foregroundColor(ArchiveTheme.textMuted)
                                  .padding(.top, 2)
                          }

                          divider

                          // Genre chips
                          genreSection

                          divider

                          // Watchlist chips
                          watchlistSection

                          divider

                          // Watched toggle
                          Button {
                              toggleWatched()
                          } label: {
                              Label(currentItem.watched ? "Mark as Unwatched" : "Mark as Watched",
                                    systemImage: currentItem.watched ? "checkmark.circle.fill" : "circle")
                                  .font(ArchiveTheme.bodyFont(size: 18))
                                  .foregroundColor(currentItem.watched ? ArchiveTheme.accent : ArchiveTheme.textMuted)
                          }

                          // Open in Apple TV
                          Button {
                              openInAppleTV()
                          } label: {
                              Text("Open in Apple TV")
                                  .font(ArchiveTheme.bodyFont(size: 20).weight(.bold))
                                  .foregroundColor(.black)
                                  .frame(maxWidth: 360)
                                  .padding(.vertical, 16)
                                  .background(ArchiveTheme.accent)
                                  .cornerRadius(6)
                          }
                          .accessibilityLabel("Open \(currentItem.title) in Apple TV")

                          // Remove
                          Button("Remove from Library", role: .destructive) {
                              showRemoveConfirm = true
                          }
                          .font(ArchiveTheme.monoFont(size: 14))
                          .foregroundColor(ArchiveTheme.textMuted)
                      }
                      .padding(40)
                  }
              }
              .padding(60)
          }
          .alert("Remove from Library", isPresented: $showRemoveConfirm) {
              Button("Remove", role: .destructive) { removeItem() }
              Button("Cancel", role: .cancel) {}
          } message: {
              Text("Remove \"\(currentItem.title)\" from your library?")
          }
          .alert("Could not open Apple TV app.", isPresented: $showOpenError) {
              Button("OK", role: .cancel) {}
          }
      }

      // MARK: - Subviews

      private var divider: some View {
          Rectangle()
              .fill(ArchiveTheme.border)
              .frame(height: 1)
      }

      private var genreSection: some View {
          VStack(alignment: .leading, spacing: 12) {
              Text("GENRES")
                  .font(ArchiveTheme.monoFont(size: 12))
                  .foregroundColor(ArchiveTheme.textMuted)
                  .kerning(3)

              FlowLayout(spacing: 8) {
                  let allGenres = predefinedGenres + currentItem.genres.filter { !predefinedGenres.contains($0) }
                  ForEach(allGenres, id: \.self) { genre in
                      genreChip(genre)
                  }
              }

              // Custom genre input
              TextField("Custom genre…", text: $customGenreInput)
                  .font(ArchiveTheme.monoFont(size: 14))
                  .foregroundColor(ArchiveTheme.textPrimary)
                  .onSubmit { addCustomGenre() }
          }
      }

      private func genreChip(_ genre: String) -> some View {
          let isSelected = currentItem.genres.contains(genre)
          return Button(genre) { toggleGenre(genre) }
              .font(ArchiveTheme.monoFont(size: 14))
              .foregroundColor(isSelected ? ArchiveTheme.accent : ArchiveTheme.textMuted)
              .padding(.horizontal, 12)
              .padding(.vertical, 5)
              .background(
                  RoundedRectangle(cornerRadius: 3)
                      .stroke(isSelected ? ArchiveTheme.accent.opacity(0.6) : ArchiveTheme.border, lineWidth: 1)
                      .background(isSelected ? ArchiveTheme.accent.opacity(0.1) : Color.clear)
              )
              .accessibilityLabel("\(genre), \(isSelected ? "selected" : "unselected")")
              .accessibilityAddTraits(.isToggle)
      }

      private var watchlistSection: some View {
          VStack(alignment: .leading, spacing: 12) {
              Text("WATCHLISTS")
                  .font(ArchiveTheme.monoFont(size: 12))
                  .foregroundColor(ArchiveTheme.textMuted)
                  .kerning(3)

              if watchlistVM.watchlists.isEmpty {
                  Text("No lists yet — create one in the Watchlists tab")
                      .font(ArchiveTheme.monoFont(size: 14))
                      .foregroundColor(ArchiveTheme.textMuted)
              } else {
                  FlowLayout(spacing: 8) {
                      ForEach(watchlistVM.watchlists) { list in
                          watchlistChip(list)
                      }
                  }
              }
          }
      }

      private func watchlistChip(_ list: Watchlist) -> some View {
          let isIn = list.itemIDs.contains(currentItem.iTunesID)
          return Button(list.name) { toggleWatchlist(list) }
              .font(ArchiveTheme.monoFont(size: 14))
              .foregroundColor(isIn ? ArchiveTheme.accent2 : ArchiveTheme.textMuted)
              .padding(.horizontal, 12)
              .padding(.vertical, 5)
              .background(
                  RoundedRectangle(cornerRadius: 3)
                      .stroke(isIn ? ArchiveTheme.accent2.opacity(0.6) : ArchiveTheme.border, lineWidth: 1)
                      .background(isIn ? ArchiveTheme.accent2.opacity(0.08) : Color.clear)
              )
              .accessibilityLabel("\(list.name), \(isIn ? "in list" : "not in list")")
              .accessibilityAddTraits(.isToggle)
      }

      // MARK: - Actions

      private func toggleGenre(_ genre: String) {
          var updated = currentItem
          if updated.genres.contains(genre) {
              updated.genres.removeAll { $0 == genre }
          } else {
              updated.genres.append(genre)
          }
          currentItem = updated
          Task { try? await ck.saveItem(updated) }
          updateLibraryVM(updated)
      }

      private func addCustomGenre() {
          let val = customGenreInput.trimmingCharacters(in: .whitespaces)
          guard !val.isEmpty, !currentItem.genres.contains(val) else { return }
          var updated = currentItem
          updated.genres.append(val)
          currentItem = updated
          customGenreInput = ""
          Task { try? await ck.saveItem(updated) }
          updateLibraryVM(updated)
      }

      private func toggleWatched() {
          var updated = currentItem
          updated.watched.toggle()
          currentItem = updated
          Task { try? await ck.saveItem(updated) }
          updateLibraryVM(updated)
      }

      private func toggleWatchlist(_ list: Watchlist) {
          guard let idx = watchlistVM.watchlists.firstIndex(where: { $0.id == list.id }) else { return }
          var updated = watchlistVM.watchlists[idx]
          if updated.itemIDs.contains(currentItem.iTunesID) {
              updated.itemIDs.removeAll { $0 == currentItem.iTunesID }
          } else {
              updated.itemIDs.append(currentItem.iTunesID)
          }
          watchlistVM.watchlists[idx] = updated
          Task { try? await ck.saveWatchlist(updated) }
      }

      private func removeItem() {
          Task {
              try? await ck.deleteItem(currentItem)
              // Prune from all watchlists
              let liveIDs = Set(libraryVM.items.map(\.iTunesID)).subtracting([currentItem.iTunesID])
              await watchlistVM.pruneStale(liveITunesIDs: liveIDs, using: ck)
              libraryVM.items.removeAll { $0.id == currentItem.id }
              await MainActor.run { dismiss() }
          }
      }

      private func openInAppleTV() {
          let urlString = currentItem.type == .film
              ? "videos://itunes.apple.com/movie?id=\(currentItem.iTunesID)"
              : "videos://itunes.apple.com/show?id=\(currentItem.iTunesID)"
          guard let url = URL(string: urlString) else { return }
          UIApplication.shared.open(url, options: [:]) { success in
              if !success { showOpenError = true }
          }
      }

      private func updateLibraryVM(_ updated: LibraryItem) {
          if let idx = libraryVM.items.firstIndex(where: { $0.id == updated.id }) {
              libraryVM.items[idx] = updated
          }
      }
  }

  // MARK: - FlowLayout (wrapping HStack for chips)
  struct FlowLayout: Layout {
      var spacing: CGFloat = 8
      func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
          let width = proposal.width ?? .infinity
          var x: CGFloat = 0, y: CGFloat = 0, maxH: CGFloat = 0
          for view in subviews {
              let size = view.sizeThatFits(.unspecified)
              if x + size.width > width { x = 0; y += maxH + spacing; maxH = 0 }
              x += size.width + spacing
              maxH = max(maxH, size.height)
          }
          return CGSize(width: width, height: y + maxH)
      }
      func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
          var x = bounds.minX, y = bounds.minY, maxH: CGFloat = 0
          for view in subviews {
              let size = view.sizeThatFits(.unspecified)
              if x + size.width > bounds.maxX { x = bounds.minX; y += maxH + spacing; maxH = 0 }
              view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
              x += size.width + spacing
              maxH = max(maxH, size.height)
          }
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  Cmd+B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

  ```bash
  git add TheArchive/Views/Library/DetailSheetView.swift
  git commit -m "feat: add DetailSheetView with genre, watchlist, watched toggle, and deep link"
  ```

---

## Task 12: Search View

**Files:**
- Create: `TheArchive/Views/Search/SearchView.swift`

- [ ] **Step 1: Write SearchView.swift**

  ```swift
  // TheArchive/Views/Search/SearchView.swift
  import SwiftUI

  struct SearchView: View {
      @EnvironmentObject var searchVM: SearchViewModel
      @EnvironmentObject var libraryVM: LibraryViewModel
      @EnvironmentObject var ck: CloudKitService

      @State private var pendingResult: iTunesResult? = nil
      @State private var showDuplicateAlert = false
      @State private var duplicateTitle = ""

      private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

      var body: some View {
          ZStack {
              ArchiveTheme.background.ignoresSafeArea()

              VStack(spacing: 0) {
                  // Search bar
                  TextField("Search films and TV shows…", text: $searchVM.query)
                      .font(ArchiveTheme.bodyFont(size: 20))
                      .foregroundColor(ArchiveTheme.textPrimary)
                      .padding(16)
                      .background(ArchiveTheme.surface)
                      .overlay(Rectangle().frame(height: 1).foregroundColor(ArchiveTheme.border), alignment: .bottom)
                      .onSubmit {
                          Task { await searchVM.search(existingIDs: Set(libraryVM.items.map(\.iTunesID))) }
                      }

                  // Error / empty state
                  if let error = searchVM.errorMessage {
                      Text(error)
                          .font(ArchiveTheme.monoFont(size: 16))
                          .foregroundColor(ArchiveTheme.textMuted)
                          .padding(40)
                      Spacer()
                  } else if searchVM.isSearching {
                      Spacer()
                      ProgressView().tint(ArchiveTheme.accent)
                      Spacer()
                  } else {
                      ScrollView {
                          LazyVGrid(columns: columns, spacing: 24) {
                              ForEach(searchVM.results) { result in
                                  Button { confirmAdd(result) } label: {
                                      searchCard(result)
                                  }
                                  .buttonStyle(.plain)
                              }
                          }
                          .padding(40)
                      }
                  }
              }
          }
          .alert("Add to Library", isPresented: Binding(get: { pendingResult != nil }, set: { if !$0 { pendingResult = nil } })) {
              Button("Add") {
                  if let r = pendingResult { Task { await addItem(r) } }
                  pendingResult = nil
              }
              Button("Cancel", role: .cancel) { pendingResult = nil }
          } message: {
              Text("Add \"\(pendingResult?.title ?? "")\" to your library?")
          }
          .alert("Already in Library", isPresented: $showDuplicateAlert) {
              Button("OK", role: .cancel) {}
          } message: {
              Text("\"\(duplicateTitle)\" is already in your library.")
          }
      }

      private func searchCard(_ result: iTunesResult) -> some View {
          VStack(alignment: .leading, spacing: 0) {
              AsyncImage(url: URL(string: result.artworkURL)) { phase in
                  if let img = phase.image {
                      img.resizable().scaledToFill()
                  } else {
                      ArchiveTheme.posterGradient(for: result.title)
                  }
              }
              .frame(width: 220, height: 330)
              .clipped()
              .cornerRadius(6)
              .overlay(RoundedRectangle(cornerRadius: 6).stroke(ArchiveTheme.border, lineWidth: 1))

              VStack(alignment: .leading, spacing: 4) {
                  Text(result.title)
                      .font(ArchiveTheme.bodyFont(size: 16))
                      .foregroundColor(ArchiveTheme.textPrimary)
                      .lineLimit(2)
                  Text(result.type == .film ? "\(result.year) · FILM" : "SERIES · \(result.year)")
                      .font(ArchiveTheme.monoFont(size: 12))
                      .foregroundColor(ArchiveTheme.textMuted)
              }
              .padding(.top, 8)
              .frame(width: 220, alignment: .leading)
          }
      }

      private func confirmAdd(_ result: iTunesResult) {
          let existingIDs = Set(libraryVM.items.map(\.iTunesID))
          if SearchViewModel.isDuplicate(iTunesID: result.id, existingIDs: existingIDs) {
              duplicateTitle = result.title
              showDuplicateAlert = true
          } else {
              pendingResult = result
          }
      }

      private func addItem(_ result: iTunesResult) async {
          let catalogID = await ck.nextCatalogID(type: result.type)
          let item = LibraryItem(
              id: UUID().uuidString,
              catalogID: catalogID,
              iTunesID: result.id,
              title: result.title,
              year: result.year,
              type: result.type,
              artworkURL: result.artworkURL,
              genres: [],
              watched: false,
              dateAdded: Date()
          )
          try? await ck.saveItem(item)
          await MainActor.run { libraryVM.items.append(item) }
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  Cmd+B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

  ```bash
  git add TheArchive/Views/Search/SearchView.swift
  git commit -m "feat: add SearchView with iTunes search, duplicate check, and add-to-library flow"
  ```

---

## Task 13: Watchlists View

**Files:**
- Create: `TheArchive/Views/Watchlists/WatchlistsView.swift`

- [ ] **Step 1: Write WatchlistsView.swift**

  ```swift
  // TheArchive/Views/Watchlists/WatchlistsView.swift
  import SwiftUI

  struct WatchlistsView: View {
      @EnvironmentObject var watchlistVM: WatchlistViewModel
      @EnvironmentObject var libraryVM: LibraryViewModel
      @EnvironmentObject var ck: CloudKitService

      @State private var newListName = ""
      @State private var showNewListInput = false
      @State private var listToRename: Watchlist? = nil
      @State private var renameText = ""
      @State private var listToDelete: Watchlist? = nil

      private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

      var body: some View {
          NavigationSplitView {
              // Sidebar
              ZStack {
                  ArchiveTheme.surface.ignoresSafeArea()
                  VStack(alignment: .leading, spacing: 0) {
                      // New list button
                      Button {
                          showNewListInput = true
                      } label: {
                          Label("New List", systemImage: "plus")
                              .font(ArchiveTheme.monoFont(size: 16))
                              .foregroundColor(ArchiveTheme.accent)
                      }
                      .padding(20)

                      Divider().background(ArchiveTheme.border)

                      List(watchlistVM.watchlists, selection: $watchlistVM.selectedListID) { list in
                          Text(list.name)
                              .font(ArchiveTheme.bodyFont(size: 18))
                              .foregroundColor(watchlistVM.selectedListID == list.id ? ArchiveTheme.accent : ArchiveTheme.textPrimary)
                              .tag(list.id)
                              .contextMenu {
                                  Button("Rename") {
                                      listToRename = list
                                      renameText = list.name
                                  }
                                  Button("Delete", role: .destructive) {
                                      listToDelete = list
                                  }
                              }
                      }
                      .listStyle(.sidebar)
                      .scrollContentBackground(.hidden)
                      .background(ArchiveTheme.surface)
                  }
              }
          } detail: {
              // Right panel: filtered grid
              ZStack {
                  ArchiveTheme.background.ignoresSafeArea()
                  if let list = watchlistVM.selectedList {
                      let items = libraryVM.items.filter { list.itemIDs.contains($0.iTunesID) }
                      if items.isEmpty {
                          Text("No titles in this list yet.\nAdd them from the Library.")
                              .font(ArchiveTheme.monoFont(size: 18))
                              .foregroundColor(ArchiveTheme.textMuted)
                              .multilineTextAlignment(.center)
                      } else {
                          ScrollView {
                              LazyVGrid(columns: columns, spacing: 24) {
                                  ForEach(items) { item in
                                      NavigationLink(value: item) {
                                          PosterCardView(item: item)
                                      }
                                      .buttonStyle(.plain)
                                  }
                              }
                              .padding(40)
                          }
                      }
                  } else {
                      Text("Select a list")
                          .font(ArchiveTheme.monoFont(size: 18))
                          .foregroundColor(ArchiveTheme.textMuted)
                  }
              }
              .navigationDestination(for: LibraryItem.self) { item in
                  DetailSheetView(item: item)
              }
          }
          .alert("New List", isPresented: $showNewListInput) {
              TextField("List name", text: $newListName)
              Button("Create") { createList() }
              Button("Cancel", role: .cancel) { newListName = "" }
          }
          .alert("Rename List", isPresented: Binding(get: { listToRename != nil }, set: { if !$0 { listToRename = nil } })) {
              TextField("New name", text: $renameText)
              Button("Rename") { renameList() }
              Button("Cancel", role: .cancel) { listToRename = nil }
          }
          .alert("Delete List", isPresented: Binding(get: { listToDelete != nil }, set: { if !$0 { listToDelete = nil } })) {
              Button("Delete", role: .destructive) { deleteList() }
              Button("Cancel", role: .cancel) { listToDelete = nil }
          } message: {
              Text("Delete \"\(listToDelete?.name ?? "")\"? This cannot be undone.")
          }
      }

      private func createList() {
          let name = newListName.trimmingCharacters(in: .whitespaces)
          guard !name.isEmpty else { return }
          let list = Watchlist(id: UUID().uuidString, name: name, itemIDs: [])
          watchlistVM.watchlists.append(list)
          Task { try? await ck.saveWatchlist(list) }
          newListName = ""
      }

      private func renameList() {
          guard let list = listToRename,
                let idx = watchlistVM.watchlists.firstIndex(where: { $0.id == list.id }) else { return }
          let name = renameText.trimmingCharacters(in: .whitespaces)
          guard !name.isEmpty else { return }
          var updated = watchlistVM.watchlists[idx]
          updated.name = name
          watchlistVM.watchlists[idx] = updated
          Task { try? await ck.saveWatchlist(updated) }
          listToRename = nil
      }

      private func deleteList() {
          guard let list = listToDelete else { return }
          watchlistVM.watchlists.removeAll { $0.id == list.id }
          if watchlistVM.selectedListID == list.id { watchlistVM.selectedListID = nil }
          Task { try? await ck.deleteWatchlist(list) }
          listToDelete = nil
      }
  }
  ```

- [ ] **Step 2: Build to verify**

  Cmd+B. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

  ```bash
  git add TheArchive/Views/Watchlists/WatchlistsView.swift
  git commit -m "feat: add WatchlistsView with NavigationSplitView, create/rename/delete lists"
  ```

---

## Task 14: App Entry Point & Data Loading

**Files:**
- Modify: `TheArchive/TheArchiveApp.swift`

- [ ] **Step 1: Wire offline detection into LibraryViewModel**

  Add `NWPathMonitor` to `LibraryViewModel.swift` to drive `isOffline`:

  ```swift
  // Add at the top of LibraryViewModel.swift
  import Network

  // Add inside LibraryViewModel class body, after @Published declarations:
  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue(label: "archive.network")

  func startMonitoring() {
      monitor.pathUpdateHandler = { [weak self] path in
          DispatchQueue.main.async {
              self?.isOffline = path.status != .satisfied
          }
      }
      monitor.start(queue: monitorQueue)
  }
  ```

  Then call `libraryVM.startMonitoring()` in `TheArchiveApp.init()` (see Step 2).

- [ ] **Step 2: Write TheArchiveApp.swift**

  ```swift
  // TheArchive/TheArchiveApp.swift
  import SwiftUI

  @main
  struct TheArchiveApp: App {
      @StateObject private var auth = AuthService()
      @StateObject private var ck = CloudKitService()
      @StateObject private var libraryVM = LibraryViewModel()
      @StateObject private var searchVM = SearchViewModel()
      @StateObject private var watchlistVM = WatchlistViewModel()

      init() {
          libraryVM.startMonitoring()
      }

      var body: some Scene {
          WindowGroup {
              Group {
                  if auth.isSignedIn {
                      TabView {
                          LibraryView()
                              .tabItem { Label("Library", systemImage: "film") }
                          WatchlistsView()
                              .tabItem { Label("Watchlists", systemImage: "list.bullet") }
                          SearchView()
                              .tabItem { Label("Search", systemImage: "magnifyingglass") }
                      }
                      .task { await loadData() }
                  } else {
                      SignInView()
                  }
              }
              .preferredColorScheme(.dark)
              .environmentObject(auth)
              .environmentObject(ck)
              .environmentObject(libraryVM)
              .environmentObject(searchVM)
              .environmentObject(watchlistVM)
              .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                  Task { await auth.checkCredentialState() }
              }
          }
      }

      private func loadData() async {
          libraryVM.isLoading = true
          async let items = try? ck.fetchAllItems()
          async let lists = try? ck.fetchAllWatchlists()
          let (fetchedItems, fetchedLists) = await (items, lists)
          libraryVM.items = fetchedItems ?? []
          watchlistVM.watchlists = fetchedLists ?? []

          // Prune stale watchlist references
          let liveIDs = Set((fetchedItems ?? []).map(\.iTunesID))
          await watchlistVM.pruneStale(liveITunesIDs: liveIDs, using: ck)

          libraryVM.isLoading = false
      }
  }
  ```

- [ ] **Step 2: Build and run on tvOS simulator**

  Cmd+R on a tvOS simulator. Expected: Sign In screen appears with gold "The Archive" title.

- [ ] **Step 3: Commit**

  ```bash
  git add TheArchive/TheArchiveApp.swift
  git commit -m "feat: wire up app entry point with TabView, environment objects, and data loading"
  ```

---

## Task 15: CloudKit Schema Setup

- [ ] **Step 1: Run app on simulator, perform first CloudKit operation**

  In Xcode: open the CloudKit Dashboard sandbox for your container.
  Navigate to: [https://icloud.developer.apple.com/dashboard](https://icloud.developer.apple.com/dashboard) → your container → Development schema.

- [ ] **Step 2: Verify record types were auto-created**

  CloudKit creates record types automatically on first save. Confirm these exist:
  - `LibraryItem` with all fields
  - `Watchlist` with all fields
  - `LibraryCounter` with `filmCount` and `seriesCount`

  If fields are missing, add them manually in the CloudKit Dashboard.

- [ ] **Step 3: Set indexes for query support**

  In CloudKit Dashboard → `LibraryItem` → Indexes:
  - Add **Queryable** index on `iTunesID` (required for duplicate check query)
  - Add **Sortable** index on `dateAdded`

- [ ] **Step 4: Commit note**

  ```bash
  git commit --allow-empty -m "chore: CloudKit schema verified — LibraryItem, Watchlist, LibraryCounter indexes set"
  ```

---

## Task 16: End-to-End Testing on Device

- [ ] **Step 1: Run on a real Apple TV**

  Connect your Apple TV 4K to Xcode (Devices & Simulators → + → Add device via network).
  Select it as the run destination. Cmd+R.

- [ ] **Step 2: Sign in flow**

  - App shows Sign In screen
  - Tap "Sign in with Apple" — completes via Siri Remote + on-screen keyboard
  - Library tab appears (empty state)

- [ ] **Step 3: Search and add a title**

  - Navigate to Search tab
  - Search "Inception" → results appear with artwork
  - Select → "Add to Library?" → confirm
  - Navigate to Library → Inception appears with poster

- [ ] **Step 4: Detail sheet**

  - Select Inception → Detail sheet opens
  - Toggle a genre chip — persists after closing and reopening
  - Tap "Open in Apple TV" → Apple TV app opens to that title (or search fallback)
  - Validate the deep link. If `videos://itunes.apple.com/movie?id=...` fails, switch to `videos://itunes.apple.com/search?term=Inception`

- [ ] **Step 5: Watchlist flow**

  - Create a watchlist "Test List"
  - Open Inception detail → toggle "Test List" chip
  - Navigate to Watchlists tab → "Test List" shows Inception

- [ ] **Step 6: Watched toggle**

  - Mark Inception as Watched
  - Close app, reopen — Inception still marked as Watched (CloudKit sync verified)

- [ ] **Step 7: Remove from library**

  - Open Inception detail → Remove from Library → confirm
  - Library grid is empty again

- [ ] **Step 8: Commit**

  ```bash
  git commit --allow-empty -m "test: end-to-end device testing complete — all flows verified"
  ```

---

## Task 17: App Store Submission Prep

- [ ] **Step 1: Create app icon assets**

  In Xcode → Assets.xcassets → App Icon:
  Create the tvOS icon set. Required sizes: 400×240 (App Store), 1280×768 (Top Shelf), 240×180, 1920×720. Use a dark `#0a0806` background with the gold "The Archive" wordmark in Playfair Display.

- [ ] **Step 2: Set bundle version and build number**

  Target → General: Version `1.0`, Build `1`.

- [ ] **Step 3: Archive and validate**

  Product → Archive → Distribute App → App Store Connect → Validate. Fix any issues flagged.

- [ ] **Step 4: Take App Store screenshots**

  Use Xcode Simulator (tvOS, 1920×1080). Take screenshots of:
  - Sign In screen
  - Library grid with titles
  - Detail sheet open
  - Search results

- [ ] **Step 5: Submit via App Store Connect**

  Upload build, fill out metadata, attach screenshots, submit for review.

- [ ] **Step 6: Final commit**

  ```bash
  git add .
  git commit -m "chore: app store submission — v1.0 build 1"
  ```

---

## Summary

| Task | Deliverable |
|------|-------------|
| 1 | Xcode project, capabilities, fonts, PrivacyInfo |
| 2 | Theme system (colors, fonts, gradients) |
| 3 | Data models + CKRecord mapping |
| 4 | iTunes Search Service |
| 5 | Auth Service (Sign in with Apple) |
| 6 | CloudKit Service (CRUD, counter, pruning) |
| 7 | ViewModels with pure testable logic |
| 8 | Sign In View |
| 9 | Poster Card + Genre Pills |
| 10 | Library View |
| 11 | Detail Sheet |
| 12 | Search View |
| 13 | Watchlists View |
| 14 | App entry point + data loading |
| 15 | CloudKit schema setup |
| 16 | End-to-end device testing |
| 17 | App Store submission |
