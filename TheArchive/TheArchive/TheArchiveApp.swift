import SwiftUI

@main
struct TheArchiveApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var ck = CloudKitService()
    @StateObject private var libraryVM = LibraryViewModel()
    @StateObject private var searchVM = SearchViewModel()
    @StateObject private var watchlistVM = WatchlistViewModel()

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
                    .task {
                        libraryVM.startMonitoring()
                        await loadData()
                    }
                } else {
                    SignInView()
                }
            }
            // SIMULATOR TESTING ONLY — remove before shipping
            .onAppear { auth.isSignedIn = true }
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

        // SIMULATOR MOCK DATA — remove before shipping
        libraryVM.items = [
            LibraryItem(id: "1", catalogID: "MV-0001", iTunesID: "401089509",
                        title: "Inception", year: 2010, type: .film,
                        artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Video116/v4/99/98/ca/9998ca6e-5e30-f9a1-1a1f-974ea3c7b2a9/source/600x600bb.jpg",
                        genres: ["Sci-Fi", "Action"], watched: false, dateAdded: Date()),
            LibraryItem(id: "2", catalogID: "MV-0002", iTunesID: "146520815",
                        title: "The Godfather", year: 1972, type: .film,
                        artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Video/v4/73/0e/44/730e4401-c7c4-9cb3-d7bb-8d8e88b8ec61/source/600x600bb.jpg",
                        genres: ["Crime", "Drama"], watched: true, dateAdded: Date()),
            LibraryItem(id: "3", catalogID: "MV-0003", iTunesID: "1468204842",
                        title: "Parasite", year: 2019, type: .film,
                        artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Video123/v4/5d/b3/b2/5db3b2b0-9a35-9a44-2a22-8f8b1f7c5b4b/source/600x600bb.jpg",
                        genres: ["Drama", "Thriller"], watched: true, dateAdded: Date()),
            LibraryItem(id: "4", catalogID: "MV-0004", iTunesID: "1053805649",
                        title: "The Revenant", year: 2015, type: .film,
                        artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Video49/v4/ae/3e/6c/ae3e6c5c-4a4e-3e44-b3b4-4f4f3c4c5c5c/source/600x600bb.jpg",
                        genres: ["Drama", "Adventure"], watched: false, dateAdded: Date()),
            LibraryItem(id: "5", catalogID: "SV-0001", iTunesID: "1537680095",
                        title: "The Bear", year: 2022, type: .series,
                        artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Video116/v4/5f/5e/2e/5f5e2e2e-2e2e-2e2e-2e2e-2e2e2e2e2e2e/source/600x600bb.jpg",
                        genres: ["Drama"], watched: false, dateAdded: Date()),
            LibraryItem(id: "6", catalogID: "SV-0002", iTunesID: "1480796860",
                        title: "Severance", year: 2022, type: .series,
                        artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Video116/v4/3e/3e/3e/3e3e3e3e-3e3e-3e3e-3e3e-3e3e3e3e3e3e/source/600x600bb.jpg",
                        genres: ["Sci-Fi", "Thriller"], watched: false, dateAdded: Date()),
            LibraryItem(id: "7", catalogID: "MV-0005", iTunesID: "361576510",
                        title: "Interstellar", year: 2014, type: .film,
                        artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Video69/v4/4e/4e/4e/4e4e4e4e-4e4e-4e4e-4e4e-4e4e4e4e4e4e/source/600x600bb.jpg",
                        genres: ["Sci-Fi", "Drama"], watched: true, dateAdded: Date()),
            LibraryItem(id: "8", catalogID: "SV-0003", iTunesID: "1190843382",
                        title: "Succession", year: 2018, type: .series,
                        artworkURL: "https://is1-ssl.mzstatic.com/image/thumb/Video116/v4/5e/5e/5e/5e5e5e5e-5e5e-5e5e-5e5e-5e5e5e5e5e5e/source/600x600bb.jpg",
                        genres: ["Drama"], watched: true, dateAdded: Date()),
        ]
        watchlistVM.watchlists = [
            Watchlist(id: "w1", name: "Weekend Watch", itemIDs: ["401089509", "1537680095"]),
            Watchlist(id: "w2", name: "Classics", itemIDs: ["146520815"]),
        ]

        libraryVM.isLoading = false
    }
}
