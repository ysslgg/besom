import AppKit
import Combine

@MainActor
final class CleanerModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case cleaning(done: Int, total: Int)
        case done(freed: Int64, trashed: Int64, failed: Int)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var results: [CategoryResult] = CategoryID.allCases.map { CategoryResult(id: $0) }
    /// Chemins cochés.
    @Published private(set) var selected: Set<String> = []
    /// Boîte de confirmation affichée avant toute suppression.
    @Published var confirming = false
    @Published private(set) var lastScan: Date?
    @Published private(set) var hasScanned = false

    private var seen: Set<String> = []
    private var scanTask: Task<Void, Never>?
    private var timer: Timer?

    // MARK: Totaux

    var totalSize: Int64 { results.reduce(0) { $0 + $1.totalSize } }
    var selectedSize: Int64 { results.flatMap(\.items).filter { selected.contains($0.id) }.reduce(0) { $0 + $1.size } }
    var isBusy: Bool {
        switch phase {
        case .scanning, .cleaning: true
        default: false
        }
    }

    func result(_ id: CategoryID) -> CategoryResult { results.first { $0.id == id } ?? CategoryResult(id: id) }

    func selectedSize(in id: CategoryID) -> Int64 {
        result(id).items.filter { selected.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    enum Tri { case none, some, all }
    func state(of id: CategoryID) -> Tri {
        let items = result(id).items
        let n = items.filter { selected.contains($0.id) }.count
        return n == 0 ? .none : (n == items.count ? .all : .some)
    }

    // MARK: Sélection

    func toggle(_ id: CategoryID) {
        let ids = result(id).items.map(\.id)
        if state(of: id) == .all { selected.subtract(ids) } else { selected.formUnion(ids) }
        confirming = false
    }

    func toggle(_ item: CleanItem) {
        if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
        confirming = false
    }

    // MARK: Cycle de vie

    func start() {
        scan()
        let t = Timer(timeInterval: 3 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Prefs.shared.autoScan, !self.isBusy else { return }
                self.scan()
            }
        }
        t.tolerance = 600
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Analyse

    func scan() {
        guard !isBusy else { return }
        phase = .scanning
        confirming = false
        scanTask = Task { [weak self] in
            let apps = await Task.detached(priority: .utility) { InstalledApps.scan() }.value
            var fresh: [CategoryID: CategoryResult] = [:]
            for id in CategoryID.allCases {
                let r = await Task.detached(priority: .utility) { Scanner.scan(id, apps: apps) }.value
                fresh[id] = r
                guard let self else { return }
                // Les lignes apparaissent au fur et à mesure.
                if let i = self.results.firstIndex(where: { $0.id == id }) { self.results[i] = r }
            }
            guard let self else { return }
            let previous = self.selected
            let known = self.seen
            var next: Set<String> = []
            for r in self.results {
                for item in r.items {
                    // Un élément déjà vu garde le choix de l'utilisateur ; un nouveau suit la règle de sa famille.
                    if known.contains(item.id) ? previous.contains(item.id) : r.id.selectedByDefault { next.insert(item.id) }
                    self.seen.insert(item.id)
                }
            }
            self.selected = next
            self.hasScanned = true
            self.lastScan = Date()
            self.phase = .idle
        }
    }

    // MARK: Nettoyage

    func clean() {
        guard !isBusy else { return }
        let items = results.flatMap(\.items).filter { selected.contains($0.id) }
        guard !items.isEmpty else { return }
        confirming = false
        phase = .cleaning(done: 0, total: items.count)
        Task { [weak self] in
            let report = await Task.detached(priority: .userInitiated) {
                Remover.remove(items) { done, total in
                    Task { @MainActor in self?.phase = .cleaning(done: done, total: total) }
                }
            }.value
            guard let self else { return }
            self.phase = .done(freed: report.freed, trashed: report.trashed, failed: report.failed + report.refused)
            if Prefs.shared.haptics {
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
            }
            // Réanalyse pour refléter l'état réel du disque, en gardant le message de bilan affiché.
            await self.rescanKeepingSummary()
        }
    }

    private func rescanKeepingSummary() async {
        let summary = phase
        let apps = await Task.detached(priority: .utility) { InstalledApps.scan() }.value
        for id in CategoryID.allCases {
            let r = await Task.detached(priority: .utility) { Scanner.scan(id, apps: apps) }.value
            if let i = results.firstIndex(where: { $0.id == id }) { results[i] = r }
        }
        let alive = Set(results.flatMap(\.items).map(\.id))
        selected = selected.intersection(alive)
        lastScan = Date()
        phase = summary
    }

    /// Le bilan disparaît dès qu'on rouvre l'encoche ou qu'on relance une analyse.
    func dismissSummary() {
        if case .done = phase { phase = .idle }
    }
}
