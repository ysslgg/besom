import Foundation

struct RemovalReport {
    /// Octets réellement libérés (suppression définitive).
    var freed: Int64 = 0
    /// Octets mis à la corbeille : ils ne se libèrent qu'au vidage de la corbeille.
    var trashed: Int64 = 0
    var removed = 0
    var failed = 0
    var refused = 0
}

/// Seul endroit de l'app qui supprime quoi que ce soit.
enum Remover {
    /// Garde-fou : l'élément doit se trouver strictement sous un dossier autorisé pour sa famille, une fois
    /// le chemin de son dossier parent résolu (un lien symbolique ne peut donc pas faire sortir de la zone).
    static func isAllowed(_ item: CleanItem) -> Bool {
        let parent = item.url.deletingLastPathComponent().resolvingSymlinksInPath().path
        let name = item.url.lastPathComponent
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/") else { return false }
        guard !ScanRules.current.isExcluded(item.url) else { return false }
        return item.category.allowedRoots.contains { root in
            let r = root.resolvingSymlinksInPath().path
            return r.count > 1 && (parent == r || parent.hasPrefix(r + "/"))
        }
    }

    static func remove(_ items: [CleanItem], progress: (Int, Int) -> Void = { _, _ in }) -> RemovalReport {
        var report = RemovalReport()
        let fm = FileManager.default
        for (index, item) in items.enumerated() {
            progress(index, items.count)
            guard isAllowed(item) else { report.refused += 1; continue }
            // L'élément a pu disparaître depuis le scan : rien à faire.
            guard (try? item.url.checkResourceIsReachable()) == true || fm.fileExists(atPath: item.url.path) else { continue }
            do {
                switch item.category.disposal {
                case .delete:
                    try fm.removeItem(at: item.url)
                    report.freed += item.size
                case .trash:
                    try fm.trashItem(at: item.url, resultingItemURL: nil)
                    report.trashed += item.size
                }
                report.removed += 1
            } catch {
                report.failed += 1
                NSLog("Besom: could not remove \(item.url.path): \(error.localizedDescription)")
            }
        }
        progress(items.count, items.count)
        return report
    }
}
