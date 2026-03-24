# The Archive — tvOS App Design Spec

**Date:** 2026-03-22
**Platform:** tvOS only (v1)
**Status:** Draft

---

## Overview

A native tvOS app on the App Store that lets users manage a personal film and TV library. Users sign in with Apple, manually curate their purchased/watched titles by searching the iTunes catalog, and can open any title directly in the Apple TV app. The visual design carries the aesthetic of `archive.html` — cinematic gold/crimson on near-black, Playfair Display + Courier Prime typography.

---

## Architecture

No backend. Fully on-device and iCloud-synced.

| Layer | Technology |
|---|---|
| Identity | Sign in with Apple |
| Library storage & sync | CloudKit (private database) |
| Metadata & artwork | iTunes Search API |
| Deep links to Apple TV | `videos://` URL scheme |
| UI framework | SwiftUI (tvOS) |

---

## Navigation Model

`TabView` (top tab bar on tvOS) with three tabs:

1. **Library** — main poster grid
2. **Watchlists** — named collections
3. **Search** — add new titles to library

A focusable **account button** (person icon) sits in the top-right corner of the Library tab toolbar, revealing a sign-out confirmation when selected.

---

## Screens

### 1. Sign In
- Shown on first launch and whenever the Apple ID credential is revoked or the iCloud account changes
- Sign in with Apple button (centered, large)
- App logo (Playfair Display italic, gold) and tagline
- After successful sign-in → Library tab
- The re-auth prompt is non-dismissable. Unsaved queued offline writes are discarded on credential change (CloudKit record ownership would be wrong for the new account). Existing CloudKit data remains — it is associated with the iCloud account, not the app.
- Credential validity is checked via `ASAuthorizationAppleIDProvider.getCredentialState` on each app foreground.

### 2. Library (Home Tab)
- Full-screen poster grid (`auto-fill`, min 220px columns, 16px gap)
- **Top toolbar** (focus traversal order, left → right):
  1. Segmented control: All / Films / Series
  2. Genre filter pills (horizontal scroll, focusable row)
  3. Search field (activates on Select → presents full-screen keyboard overlay; searches locally in-library by title text; results update live; dismiss with Menu button to return to grid)
  4. Sort button (Select → presents a focused `Menu`/picker: A–Z, Z–A, Year Newest, Year Oldest, Newest Added)
- After interacting with the toolbar, focus returns to the poster grid via a down d-pad press
- Stats bar below toolbar: `{n} Films · {n} Series · {n} Total` — counts reflect the **current filtered view**
- Empty state: *"Nothing here yet — head to Search to add your first title."*
- Select on any card → Detail sheet

**Genre filter pills:** Shows only genres that are assigned to at least one item in the **current filtered view** (All / Films / Series). "All Genres" pill always present and selected by default. Pills are sorted alphabetically.

### 3. Search & Add (Search Tab)
- Full-screen search: text input at top (presented with tvOS keyboard overlay on tab focus), results grid below
- Queries iTunes Search API on search commit (return key), not live-typing (respects ~20 req/min rate limit)
- Results grid: poster artwork, title, year, type badge
- TV shows display `releaseYear` from the collection-level iTunes result
- Select on a result → confirmation alert: "Add '{title}' to your library?" → Yes / Cancel
- On confirm: creates `LibraryItem`, syncs to CloudKit, dismisses alert
- **Duplicate check:** before writing, query CloudKit for a record where `iTunesID == result.id`. If found, show alert: "'{title}' is already in your library." Do not add.
- `iTunesID` (the deduplication key) is a String storing the integer ID as a string: `"\(trackId)"` for films, `"\(collectionId)"` for TV shows. Conversion happens at add time.
- Error states:
  - No network: "No connection — check your network and try again"
  - Empty results: "No results for "{query}""
  - API error / rate limit: "Search unavailable — try again in a moment"
  - No artwork: gradient fallback (title-hash-based gradient, matching archive.html poster system)

### 4. Detail Sheet
Full-screen sheet presented over the Library grid.

- Large poster artwork (iTunes 600×900; URL constructed by replacing the size token: `100x100bb` → `600x900bb`)
- Title (Playfair Display)
- Year · Type badge (Motion Picture / Television Series)
- Catalog reference ID (e.g. `MV-0042`) — decorative display only
- **Genre chips** — predefined list (see below) + custom input via tvOS keyboard overlay; chips are focusable toggles; VoiceOver announces "Action, selected" / "Action, unselected"
- **Watchlist chips** — one chip per watchlist, focusable toggles; VoiceOver announces list name + state
- **Watched toggle** — "Mark as Watched" / "Mark as Unwatched"
- **"Open in Apple TV"** button (gold, prominent); VoiceOver label: "Open {title} in Apple TV"
- **Remove from Library** button (muted, destructive); Select → confirmation alert: "Remove '{title}' from your library?" → Remove / Cancel. On confirm: deletes CloudKit record, prunes from all watchlists.

**Open in Apple TV failure:** if `UIApplication.shared.open(url, options: [:])` returns `false`, present a standard SwiftUI `Alert`: "Could not open Apple TV app." (No custom toast component — use system alert throughout the app for error feedback.)

**Predefined genres:** Action, Adventure, Animation, Biography, Comedy, Crime, Documentary, Drama, Fantasy, Horror, Mystery, Romance, Sci-Fi, Thriller, War, Western

### 5. Watchlists Tab
`NavigationSplitView`: watchlist sidebar on the left, selected list's poster grid on the right.

- **Create list:** "New List" button at top of sidebar → presents tvOS keyboard overlay for name input → creates `Watchlist` CloudKit record
- **Rename:** long-press (context menu) on a sidebar list item → "Rename" → keyboard overlay
- **Delete:** long-press (context menu) on a sidebar list item → "Delete" → confirmation alert → deletes CloudKit record. *Note: long-press is the canonical tvOS context menu gesture; the Menu button navigates back and is not used for context menus.*
- Stale `itemIDs` are pruned silently on watchlist load by diffing `Watchlist.itemIDs` against the set of `LibraryItem.iTunesID` values currently in CloudKit (not CKRecord IDs)
- Selecting a list filters the right-side grid to that list's items

---

## Data Model (CloudKit — Private Database)

### `LibraryItem` record type

`CKRecord.ID` is a UUID generated client-side at add time (`UUID().uuidString`). This ensures uniqueness across devices without counter collisions.

| Field | Type | Notes |
|---|---|---|
| `catalogID` | String | Display-only label: `MV-XXXX` (film) or `SV-XXXX` (series). Generated from a counter stored in CloudKit (a separate `LibraryCounter` record — see below). Never used as a relational key. |
| `iTunesID` | String | Primary deduplication key. `"\(trackId)"` for films; `"\(collectionId)"` for TV shows. Also used for deep linking. |
| `title` | String | |
| `year` | Int | Always populated. For series: `releaseYear` from iTunes collection result (first air year). |
| `type` | String | `"film"` or `"series"` |
| `artworkURL` | String | iTunes URL with `600x900bb` size token substituted at add time. |
| `genres` | [String] | User-assigned |
| `watched` | Bool | Default: `false` |
| `dateAdded` | Date | Set at add time |

> `episodes` count is omitted from v1. The iTunes API does not return a reliable episode count at the collection level without a secondary lookup. Deferred to v2.

### `LibraryCounter` record type

A single record per user (fixed `CKRecord.ID`: `"library-counter"`), used to generate sequential display-only `catalogID` labels safely across devices.

| Field | Type |
|---|---|
| `filmCount` | Int |
| `seriesCount` | Int |

On add, fetch and atomically increment the counter using a `CKModifyRecordsOperation` with `savePolicy: .ifServerRecordUnchanged`. Retry on conflict up to **3 times** with exponential backoff (0.5s, 1s, 2s). If all retries fail, the `LibraryItem` is still written to CloudKit but with a fallback `catalogID` of `MV-????` (display-only, no functional impact). Format successful result as `MV-\(String(format: "%04d", count))`.

### `Watchlist` record type

`CKRecord.ID` is a UUID generated client-side.

| Field | Type | Notes |
|---|---|---|
| `name` | String | User-defined |
| `itemIDs` | [String] | Array of `iTunesID` values — the stable relational key. Stale IDs pruned on load. |

> `itemIDs` uses `iTunesID` (not `catalogID`) as the relational key. `catalogID` is display-only and never referenced by other records.

---

## Deep Linking

```swift
func openInAppleTV(_ item: LibraryItem) {
    // iTunesID stores the integer track/collection ID as a String
    let urlString: String
    if item.type == "film" {
        urlString = "videos://itunes.apple.com/movie?id=\(item.iTunesID)"
    } else {
        urlString = "videos://itunes.apple.com/show?id=\(item.iTunesID)"
    }

    guard let url = URL(string: urlString) else { return }

    // UIApplication.shared.open is valid on tvOS; options [:] is correct
    UIApplication.shared.open(url, options: [:]) { success in
        if !success {
            // Trigger a SwiftUI Alert: "Could not open Apple TV app."
        }
    }
}
```

> **Validation required before shipping:** The `videos://itunes.apple.com/show?id={collectionId}` scheme for TV shows must be tested on a real Apple TV device. If `collectionId` does not resolve correctly, fall back to `videos://itunes.apple.com/search?term={URLEncodedTitle}`, which opens the Apple TV app's search for that title.

---

## Visual Design

| Token | Value |
|---|---|
| Background | `#0a0806` |
| Card/surface bg | `#110e0b` |
| Accent (gold) | `#c8973a` |
| Accent 2 (crimson) | `#8b2635` |
| Text | `#e8dcc8` |
| Muted | `#6b5d4a` |
| Border | `#2a2218` |
| Title font | Playfair Display (bundled — SIL Open Font License) |
| Body/mono font | Courier Prime (bundled — SIL Open Font License) |

Both fonts must be added to the Xcode target and declared under `UIAppFonts` in `Info.plist`.

**Focus engine:** Focused cards scale to 1.1× with a gold drop shadow (`#c8973a`, 40% opacity, 12pt blur). Tab bar items turn gold when focused.

**Error feedback:** All error messages use SwiftUI `Alert`. No custom toast component in v1.

---

## Offline Behavior

- **First launch, no network:** Sign In screen; "No connection. Connect to the internet to sign in."
- **Post sign-in sync:** CloudKit syncs in background; library shows a loading indicator until first sync completes
- **Offline after initial sync:** library fully readable from CloudKit local cache; add/edit/delete actions are queued by CloudKit and sync on reconnect; a persistent banner shows "Offline — changes will sync when connected"
- **Offline queue on credential revocation:** if the Apple ID credential is revoked while the app is backgrounded, queued offline writes are discarded when the re-auth prompt is shown on next foreground. CloudKit cannot sync writes for a deauthorized account. An add-then-remove sequence for the same item while offline is also discarded entirely (both operations cancelled before sync) to avoid zombie records.
- **Add-then-remove offline:** if a user adds and then removes the same title while offline (before any sync), both the pending write and delete are cancelled — the item never reaches CloudKit.

---

## CloudKit Development Notes

- Use **CloudKit simulator** (Xcode → Window → CloudKit Console sandbox) during development
- Schema is defined in the CloudKit Dashboard development environment and promoted to production before App Store submission
- Schema changes in v1 are additive only — no migration tooling needed
- `PrivacyInfo.xcprivacy` manifest is required for App Store submission (as of 2024). Must declare: CloudKit, UserDefaults (if used), and network access. This is separate from `Info.plist` usage description strings.

---

## App Store Assets Required

- **App icon:** full tvOS icon set (all required sizes)
- **Launch image:** static `#0a0806` background with centered gold app logo
- **Top Shelf extension:** not in v1. No stub required — tvOS 17+ apps can ship without one.
- **Screenshots:** tvOS screenshot set (1920×1080)
- **`PrivacyInfo.xcprivacy`:** CloudKit + network access declared
- **`Info.plist`:** `NSAppleMusicUsageDescription`, `NSiCloudUsageDescription`, `UIAppFonts` (Playfair Display, Courier Prime)

---

## Accessibility

- All interactive elements have `.accessibilityLabel` set
- VoiceOver focus order follows visual layout (top toolbar → poster grid)
- Genre and watchlist chips announced as toggles: "Action, selected" / "Action, unselected"
- "Open in Apple TV" button label: "Open {title} in Apple TV"
- Poster cards: "Film: {title}, {year}" / "Series: {title}, {year}"

---

## v1 Scope

**In scope:**
- Sign in with Apple
- Browse library (grid, segmented filter, in-library search, sort, genre filter pills)
- Add titles via iTunes Search API
- Remove titles from library
- Genre tagging (predefined + custom)
- Watched / unwatched toggle
- Custom watchlists (create, rename, delete)
- Open in Apple TV (deep link)
- iCloud sync via CloudKit
- Offline read support

**Out of scope (v1):**
- Episode count display (deferred — requires secondary iTunes API call)
- Ratings / reviews
- Social features / sharing
- Recommendations engine
- iOS / macOS companion apps
- Roku or other device control
- Top Shelf extension
- Multiple Apple ID / account switching (undefined — show re-auth prompt)
