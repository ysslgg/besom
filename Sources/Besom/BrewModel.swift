import SwiftUI

struct BrewPackage: Identifiable, Hashable {
    let name: String
    let version: String
    let isCask: Bool
    var size: Int64
    var isLeaf: Bool
    var id: String { (isCask ? "cask:" : "formula:") + name }
}

struct PackageUpdate: Identifiable, Hashable {
    enum Source: String { case formula, cask, appStore }
    let name: String
    let from: String
    let to: String
    let source: Source
    var id: String { source.rawValue + ":" + name }
}

/// Homebrew et mises à jour. Rien ne tourne en arrière-plan : les commandes ne partent que sur demande
/// (ouverture de la page, bouton, ou la vérification discrète au lancement).
@MainActor
final class BrewModel: ObservableObject {
    @Published private(set) var brewPath: String?
    @Published private(set) var masPath: String?
    @Published private(set) var packages: [BrewPackage] = []
    @Published private(set) var updates: [PackageUpdate] = []
    @Published private(set) var cacheSize: Int64 = 0
    @Published private(set) var loaded = false
    @Published private(set) var busy: String?
    @Published private(set) var lastChecked: Date?
    @Published private(set) var log: [String] = []

    var updateCount: Int { updates.count }
    var formulaCount: Int { packages.filter { !$0.isCask }.count }
    var caskCount: Int { packages.filter(\.isCask).count }

    // MARK: Lecture de l'état

    /// Charge la liste et les mises à jour (sans toucher au réseau, sauf si `updateIndex`).
    func refresh(updateIndex: Bool = false) {
        guard busy == nil else { return }
        busy = updateIndex ? tr("Updating Homebrew index…") : tr("Checking…")
        Task { await load(updateIndex: updateIndex); busy = nil }
    }

    /// Vérification discrète des mises à jour (au lancement, puis de temps en temps).
    func checkQuietly() {
        guard busy == nil, !loaded || lastChecked.map({ Date().timeIntervalSince($0) > 6 * 3600 }) ?? true else { return }
        refresh(updateIndex: !Power.onBattery && !Power.lowPowerMode)
    }

    private func load(updateIndex: Bool) async {
        brewPath = Shell.which("brew")
        masPath = Shell.which("mas")
        var list: [BrewPackage] = []
        var ups: [PackageUpdate] = []
        if let brew = brewPath {
            if updateIndex { _ = await Shell.run(brew, ["update", "--quiet"]) }
            async let formulas = Shell.run(brew, ["list", "--formula", "--versions"])
            async let casks = Shell.run(brew, ["list", "--cask", "--versions"])
            async let leaves = Shell.run(brew, ["leaves"])
            async let outdated = Shell.run(brew, ["outdated", "--json=v2"])
            let (f, c, l, o) = await (formulas, casks, leaves, outdated)
            let prefix = ((brew as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
            let leafSet = Set(l.out.split(separator: "\n").map(String.init))
            func parse(_ out: String, cask: Bool) -> [BrewPackage] {
                out.split(separator: "\n").compactMap { line in
                    let parts = line.split(separator: " ").map(String.init)
                    guard let name = parts.first else { return nil }
                    return BrewPackage(name: name, version: parts.dropFirst().last ?? "", isCask: cask, size: 0, isLeaf: cask || leafSet.contains(name))
                }
            }
            list = parse(f.out, cask: false) + parse(c.out, cask: true)
            let urls = list.map { URL(fileURLWithPath: prefix + (($0.isCask ? "/Caskroom/" : "/Cellar/") + $0.name)) }
            let sizes = await Task.detached(priority: .utility) { StorageScan.sizes(urls) }.value
            for i in list.indices { list[i].size = sizes[i] }
            list.sort { $0.size > $1.size }
            if let data = o.out.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for item in json["formulae"] as? [[String: Any]] ?? [] {
                    guard let name = item["name"] as? String else { continue }
                    let from = (item["installed_versions"] as? [String])?.last ?? ""
                    ups.append(PackageUpdate(name: name, from: from, to: item["current_version"] as? String ?? "", source: .formula))
                }
                for item in json["casks"] as? [[String: Any]] ?? [] {
                    guard let name = item["name"] as? String else { continue }
                    let from = (item["installed_versions"] as? [String])?.last ?? (item["installed_versions"] as? String ?? "")
                    ups.append(PackageUpdate(name: name, from: from, to: item["current_version"] as? String ?? "", source: .cask))
                }
            }
            let cache = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Caches/Homebrew")
            cacheSize = await Task.detached(priority: .utility) { Scanner.allocatedSize(of: cache) }.value
        }
        if let mas = masPath {
            let r = await Shell.run(mas, ["outdated"])
            for line in r.out.split(separator: "\n") {
                // « 409183694 Keynote (13.2 -> 14.0) »
                let text = String(line)
                guard let open = text.lastIndex(of: "("), let close = text.lastIndex(of: ")"), open < close else { continue }
                let versions = text[text.index(after: open)..<close].components(separatedBy: " -> ")
                let head = text[..<open].trimmingCharacters(in: .whitespaces)
                let name = head.split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init) ?? head
                ups.append(PackageUpdate(name: name, from: versions.first ?? "", to: versions.last ?? "", source: .appStore))
            }
        }
        packages = list
        updates = ups.sorted { $0.name.lowercased() < $1.name.lowercased() }
        lastChecked = Date()
        loaded = true
    }

    // MARK: Actions

    private func append(_ line: String) {
        log.append(line)
        if log.count > 400 { log.removeFirst(log.count - 400) }
    }

    /// Enchaîne des commandes en affichant leur sortie, puis recharge l'état.
    private func run(_ title: String, _ steps: [(String, [String])]) {
        guard busy == nil else { return }
        busy = title
        log = []
        Task { [weak self] in
            var failed = false
            for (exe, args) in steps {
                self?.append("$ " + ([(exe as NSString).lastPathComponent] + args).joined(separator: " "))
                let status = await Shell.stream(exe, args) { line in Task { @MainActor in self?.append(line) } }
                if status != 0 { failed = true; self?.append(tr("Finished with errors (code %d).", Int(status))); break }
            }
            guard let self else { return }
            if failed, self.log.contains(where: { $0.lowercased().contains("sudo") || $0.lowercased().contains("password") }) {
                self.append(tr("Some casks need your administrator password: run the same command in Terminal."))
            } else if !failed {
                self.append(tr("Done."))
            }
            await self.load(updateIndex: false)
            self.busy = nil
        }
    }

    func upgradeAll() {
        guard let brew = brewPath else { return }
        var steps: [(String, [String])] = [(brew, ["upgrade"])]
        if let mas = masPath, updates.contains(where: { $0.source == .appStore }) { steps.append((mas, ["upgrade"])) }
        run(tr("Updating everything…"), steps)
    }

    func upgrade(_ update: PackageUpdate) {
        switch update.source {
        case .formula:
            if let brew = brewPath { run(tr("Updating %@…", update.name), [(brew, ["upgrade", update.name])]) }
        case .cask:
            if let brew = brewPath { run(tr("Updating %@…", update.name), [(brew, ["upgrade", "--cask", update.name])]) }
        case .appStore:
            if let mas = masPath { run(tr("Updating %@…", update.name), [(mas, ["upgrade"])]) }
        }
    }

    func uninstall(_ pkg: BrewPackage, zap: Bool = false) {
        guard let brew = brewPath else { return }
        var args = ["uninstall"]
        if pkg.isCask { args.append("--cask"); if zap { args.append("--zap") } }
        args.append(pkg.name)
        run(tr("Removing %@…", pkg.name), [(brew, args)])
    }

    func cleanup() {
        if let brew = brewPath { run(tr("Cleaning Homebrew…"), [(brew, ["cleanup", "--prune=all"])]) }
    }

    func autoremove() {
        if let brew = brewPath { run(tr("Removing unused dependencies…"), [(brew, ["autoremove"])]) }
    }

    func updateIndexOnly() { refresh(updateIndex: true) }

    func installMas() {
        if let brew = brewPath { run(tr("Installing mas…"), [(brew, ["install", "mas"])]) }
    }
}
