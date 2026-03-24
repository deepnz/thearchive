import Foundation
import Combine

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
