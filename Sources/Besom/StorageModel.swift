import SwiftUI

/// Familles du graphique de stockage (proches de celles de Réglages Système → Stockage).
enum StorageGroup: String, CaseIterable, Identifiable {
    case applications, documents, desktop, downloads, movies, music, pictures
    case developer, appData, caches, trash, other, system, free
    var id: String { rawValue }

    var title: String {
        switch self {
        case .applications: tr("Applications")
        case .documents: tr("Documents")
        case .desktop: tr("Desktop")
        case .downloads: tr("Downloads")
        case .movies: tr("Movies")
        case .music: tr("Music")
        case .pictures: tr("Pictures")
        case .developer: tr("Developer")
        case .appData: tr("App data")
        case .caches: tr("Caches & logs")
        case .trash: tr("Trash")
        case .other: tr("Other files")
        case .system: tr("System & other users")
        case .free: tr("Free")
        }
    }

    var symbol: String {
        switch self {
        case .applications: "app.dashed"
        case .documents: "doc"
        case .desktop: "menubar.dock.rectangle"
        case .downloads: "arrow.down.circle"
        case .movies: "film"
        case .music: "music.note"
        case .pictures: "photo"
        case .developer: "hammer"
        case .appData: "square.stack.3d.up"
        case .caches: "internaldrive"
        case .trash: "trash"
        case .other: "folder"
        case .system: "gearshape.2"
        case .free: "circle.dashed"
        }
    }

    var color: Color {
        switch self {
        case .applications: Color(hue: 0.60, saturation: 0.65, brightness: 0.95)
        case .documents: Color(hue: 0.08, saturation: 0.70, brightness: 1.0)
        case .desktop: Color(hue: 0.13, saturation: 0.70, brightness: 1.0)
        case .downloads: Color(hue: 0.76, saturation: 0.55, brightness: 0.95)
        case .movies: Color(hue: 0.99, saturation: 0.65, brightness: 1.0)
        case .music: Color(hue: 0.92, saturation: 0.50, brightness: 1.0)
        case .pictures: Color(hue: 0.35, saturation: 0.60, brightness: 0.85)
        case .developer: Color(hue: 0.68, saturation: 0.55, brightness: 0.90)
        case .appData: Color(hue: 0.48, saturation: 0.65, brightness: 0.80)
        case .caches: Color(hue: 0.42, saturation: 0.45, brightness: 0.95)
        case .trash: Color(white: 0.55)
        case .other: Color(hue: 0.07, saturation: 0.35, brightness: 0.70)
        case .system: Color(white: 0.45)
        case .free: Color.secondary.opacity(0.22)
        }
    }
}

struct StorageUnit: Sendable {
    let url: URL
    let label: String
    let group: StorageGroup
}

struct StorageSlice: Identifiable {
    let group: StorageGroup
    var bytes: Int64
    var id: String { group.rawValue }
}

struct FolderUsage: Identifiable {
    let unit: StorageUnit
    var bytes: Int64
    var id: String { unit.url.path }
}

/// Découpe le dossier personnel en blocs mesurables et les mesure en parallèle.
enum StorageScan {
    static func units() -> [StorageUnit] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        func children(_ url: URL) -> [URL] { (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])) ?? [] }
        var out: [StorageUnit] = [StorageUnit(url: URL(fileURLWithPath: "/Applications"), label: "Applications", group: .applications)]
        let userApps = home.appendingPathComponent("Applications")
        if fm.fileExists(atPath: userApps.path) { out.append(StorageUnit(url: userApps, label: "~/Applications", group: .applications)) }

        let named: [String: StorageGroup] = ["Documents": .documents, "Desktop": .desktop, "Downloads": .downloads,
                                             "Movies": .movies, "Music": .music, "Pictures": .pictures, ".Trash": .trash]
        let devHidden: Set<String> = [".npm", ".cargo", ".rustup", ".gradle", ".m2", ".nvm", ".pyenv", ".swiftpm",
                                      ".docker", ".cache", ".bun", ".pnpm-store", ".yarn", ".android"]
        for url in children(home) {
            let name = url.lastPathComponent
            if name == "Library" {
                for sub in children(url) {
                    let n = sub.lastPathComponent
                    let group: StorageGroup = (n == "Caches" || n == "Logs") ? .caches : (n == "Developer" ? .developer : .appData)
                    out.append(StorageUnit(url: sub, label: "Library › \(n)", group: group))
                }
            } else if let g = named[name] {
                out.append(StorageUnit(url: url, label: name == ".Trash" ? "Trash" : name, group: g))
            } else {
                out.append(StorageUnit(url: url, label: name, group: devHidden.contains(name) ? .developer : .other))
            }
        }
        return out
    }

    /// Nombre de mesures simultanées : un tiers des cœurs, pour ne pas faire chauffer le Mac.
    static var concurrency: Int { max(2, ProcessInfo.processInfo.activeProcessorCount / 3) }

    private static func queue() -> OperationQueue {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = concurrency
        q.qualityOfService = .utility
        return q
    }

    /// Mesure toutes les unités ; `each` est appelé (depuis des threads de fond) à mesure qu'elles se terminent.
    static func measure(_ units: [StorageUnit], each: @escaping @Sendable (Int, Int64) -> Void) {
        let q = queue()
        for i in units.indices { q.addOperation { each(i, Scanner.allocatedSize(of: units[i].url)) } }
        q.waitUntilAllOperationsAreFinished()
    }

    /// Tailles occupées sur le disque (même ordre que `urls`).
    static func sizes(_ urls: [URL]) -> [Int64] {
        let box = SizeBox(count: urls.count)
        let q = queue()
        for i in urls.indices { q.addOperation { box.set(i, Scanner.allocatedSize(of: urls[i])) } }
        q.waitUntilAllOperationsAreFinished()
        return box.values
    }

    static func volume() -> (name: String, total: Int64, free: Int64) {
        let root = URL(fileURLWithPath: "/")
        let v = try? root.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        return (v?.volumeName ?? "Macintosh HD", Int64(v?.volumeTotalCapacity ?? 0), v?.volumeAvailableCapacityForImportantUsage ?? 0)
    }
}

@MainActor
final class StorageModel: ObservableObject {
    enum Phase { case idle, measuring, done }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var progress = 0.0
    @Published private(set) var volumeName = "Macintosh HD"
    @Published private(set) var total: Int64 = 0
    @Published private(set) var free: Int64 = 0
    @Published private(set) var slices: [StorageSlice] = []
    @Published private(set) var folders: [FolderUsage] = []

    @Published private(set) var measuredAt: Date?

    private var measured: [Int: Int64] = [:]
    private var units: [StorageUnit] = []
    private var lastPublish = Date.distantPast

    private struct CacheEntry: Codable { let path: String; let label: String; let group: String; let size: Int64 }
    private struct CacheFile: Codable { let date: Date; let entries: [CacheEntry] }

    init() {
        // Dernière mesure enregistrée : affichée tout de suite, sans reparcourir le disque.
        if let data = UserDefaults.standard.data(forKey: "storageCache"),
           let file = try? JSONDecoder().decode(CacheFile.self, from: data) {
            units = file.entries.map { StorageUnit(url: URL(fileURLWithPath: $0.path), label: $0.label, group: StorageGroup(rawValue: $0.group) ?? .other) }
            for (i, e) in file.entries.enumerated() { measured[i] = e.size }
            measuredAt = file.date
            updateVolume()
            phase = .done
            rebuild()
        }
    }

    private func updateVolume() {
        let v = StorageScan.volume()
        volumeName = v.name; total = v.total; free = v.free
    }

    private func saveCache() {
        let entries = measured.sorted { $0.key < $1.key }.map { i, size in
            CacheEntry(path: units[i].url.path, label: units[i].label, group: units[i].group.rawValue, size: size)
        }
        if let data = try? JSONEncoder().encode(CacheFile(date: Date(), entries: entries)) {
            UserDefaults.standard.set(data, forKey: "storageCache")
        }
    }

    /// Ne remesure que si la dernière mesure est ancienne (6 h) ; sinon met seulement à jour l'espace libre.
    func refreshIfNeeded() {
        updateVolume()
        guard phase != .measuring else { return }
        if let measuredAt, Date().timeIntervalSince(measuredAt) < 6 * 3600 { rebuild(); return }
        refresh()
    }

    var used: Int64 { max(0, total - free) }

    func refresh() {
        guard phase != .measuring else { return }
        updateVolume()
        phase = .measuring
        progress = 0
        measured = [:]
        let units = StorageScan.units()
        self.units = units
        rebuild()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            StorageScan.measure(units) { index, size in
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.record(index, size) } }
            }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.finish() } }
        }
    }

    private func record(_ index: Int, _ size: Int64) {
        measured[index] = size
        // Mises à jour de l'affichage groupées (quelques fois par seconde) : évite de redessiner les graphiques à chaque dossier.
        let now = Date()
        guard now.timeIntervalSince(lastPublish) > 0.5 else { return }
        lastPublish = now
        progress = Double(measured.count) / Double(max(units.count, 1))
        rebuild()
    }

    private func finish() {
        phase = .done
        progress = 1
        measuredAt = Date()
        saveCache()
        rebuild()
    }

    private func rebuild() {
        var byGroup: [StorageGroup: Int64] = [:]
        for (i, size) in measured { byGroup[units[i].group, default: 0] += size }
        var list = byGroup.filter { $0.value > 0 }.map { StorageSlice(group: $0.key, bytes: $0.value) }
            .sorted { $0.bytes > $1.bytes }
        let known = list.reduce(Int64(0)) { $0 + $1.bytes }
        // Le reste du disque (macOS, apps système, autres comptes) n'a de sens qu'une fois tout mesuré.
        if phase == .done, used > known { list.append(StorageSlice(group: .system, bytes: used - known)) }
        if free > 0 { list.append(StorageSlice(group: .free, bytes: free)) }
        slices = list
        folders = measured.compactMap { i, size in size > 0 ? FolderUsage(unit: units[i], bytes: size) : nil }
            .sorted { $0.bytes > $1.bytes }
    }
}
