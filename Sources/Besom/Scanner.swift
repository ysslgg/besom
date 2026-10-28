import AppKit

/// Parcourt les dossiers connus et propose ce qui peut partir. Ne supprime jamais rien.
enum Scanner {
    private static let fm = FileManager.default
    private static var home: URL { fm.homeDirectoryForCurrentUser }
    private static var library: URL { home.appendingPathComponent("Library") }

    private struct Candidate {
        var url: URL
        var modified: Date?
        var detail: String?
    }

    // MARK: Point d'entrée

    static func scan(_ id: CategoryID, apps: InstalledApps) -> CategoryResult {
        var result = CategoryResult(id: id)
        let rules = ScanRules.current
        if rules.disabled.contains(id.rawValue) { return result }
        var candidates: [Candidate]
        switch id {
        case .caches: candidates = caches()
        case .logs: candidates = logs()
        case .temp: candidates = temp()
        case .devCaches: candidates = devCaches()
        case .orphans: candidates = orphans(apps: apps)
        case .installers: candidates = installers()
        case .backups: candidates = backups()
        case .trash: candidates = children(of: home.appendingPathComponent(".Trash")).map { Candidate(url: $0) }
        }
        candidates = candidates.filter { !rules.isExcluded($0.url) }
        if candidates.isEmpty, id == .trash || id == .backups {
            result.needsAccess = isDenied(id.allowedRoots[0])
        }
        let sizes = measure(candidates.map(\.url))
        result.items = zip(candidates, sizes).compactMap { c, size in
            guard size > 0, size >= Int64(rules.minSizeMB) * 1_000_000 else { return nil }
            return CleanItem(url: c.url, category: id, size: size, modified: c.modified, detail: c.detail)
        }
        .sorted { $0.size > $1.size }
        return result
    }

    // MARK: Familles

    /// Caches utilisateur, hors Apple (macOS en dépend) et hors apps ouvertes en ce moment.
    private static func caches() -> [Candidate] {
        let running = runningNames()
        return children(of: library.appendingPathComponent("Caches")).compactMap { url in
            let name = url.lastPathComponent
            if name.lowercased().hasPrefix("com.apple.") || name == "CloudKit" { return nil }
            // Mises à jour d'apps en cours de téléchargement.
            if name.hasSuffix(".ShipIt") { return nil }
            if running.contains(InstalledApps.normalize(name)) { return nil }
            return Candidate(url: url, modified: modified(url))
        }
    }

    private static func logs() -> [Candidate] {
        let root = library.appendingPathComponent("Logs")
        var out: [Candidate] = []
        for url in children(of: root) {
            if url.lastPathComponent == "DiagnosticReports" {
                out += children(of: url).map { Candidate(url: $0, modified: modified($0)) }
            } else {
                out.append(Candidate(url: url, modified: modified(url)))
            }
        }
        return out
    }

    /// Dossier temporaire de l'utilisateur : seulement ce qui n'a pas bougé depuis 3 jours.
    private static func temp() -> [Candidate] {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
        let limit = Date().addingTimeInterval(-Double(ScanRules.current.tempDays) * 86_400)
        return children(of: root).compactMap { url in
            let name = url.lastPathComponent
            if name.hasPrefix(".") || name.hasPrefix("com.apple.") || name == "TemporaryItems" { return nil }
            guard let v = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey]),
                  v.isRegularFile == true || v.isDirectory == true,
                  let date = v.contentModificationDate, date < limit else { return nil }
            return Candidate(url: url, modified: date)
        }
    }

    private static func devCaches() -> [Candidate] {
        let xcode = library.appendingPathComponent("Developer/Xcode")
        var out: [Candidate] = []
        for (dir, label) in [(xcode.appendingPathComponent("DerivedData"), "Xcode DerivedData"),
                             (xcode.appendingPathComponent("iOS DeviceSupport"), "Xcode iOS DeviceSupport"),
                             (library.appendingPathComponent("Developer/CoreSimulator/Caches"), "Simulator caches")] {
            out += children(of: dir).map { Candidate(url: $0, modified: modified($0), detail: label) }
        }
        let npm = home.appendingPathComponent(".npm/_cacache")
        if fm.fileExists(atPath: npm.path) { out.append(Candidate(url: npm, modified: modified(npm), detail: "npm cache")) }
        return out
    }

    /// Données d'apps désinstallées, et lanceurs qui pointent vers un programme disparu.
    private static func orphans(apps: InstalledApps) -> [Candidate] {
        let recent = Date().addingTimeInterval(-Double(ScanRules.current.orphanDays) * 86_400)
        let protectedNames: Set<String> = [
            "addressbook", "caches", "clouddocs", "cloudstorage", "crashreporter", "dock", "fileprovider",
            "icloud", "knowledge", "mobilesync", "safari", "syncservices", "differentialprivacy", "default",
            "callhistorydb", "callhistorytransferstorage", "animoji", "mail", "messages", "photos", "com.apple",
        ]
        var out: [Candidate] = []
        let roots = ["Application Support", "Preferences", "Saved Application State", "HTTPStorages", "WebKit"]
        for root in roots {
            for url in children(of: library.appendingPathComponent(root)) {
                let name = url.lastPathComponent
                let lower = name.lowercased()
                if lower.contains("com.apple") || lower.hasPrefix(".") || protectedNames.contains(lower) { continue }
                // HTTPStorages et WebKit sont nommés d'après l'identifiant de l'app ; sans point, c'est un démon système.
                if (root == "HTTPStorages" || root == "WebKit"), !name.contains(".") { continue }
                if root == "Preferences", !lower.hasSuffix(".plist") { continue }
                if apps.owns(name) { continue }
                let date = modified(url)
                if let date, date > recent { continue }
                out.append(Candidate(url: url, modified: date, detail: lastUse(date)))
            }
        }
        // Lanceurs (LaunchAgents) dont le programme n'existe plus.
        for url in children(of: library.appendingPathComponent("LaunchAgents")) where url.pathExtension == "plist" {
            guard let plist = NSDictionary(contentsOf: url) else { continue }
            let program = (plist["Program"] as? String) ?? (plist["ProgramArguments"] as? [String])?.first
            guard let program, program.hasPrefix("/"), !fm.fileExists(atPath: program) else { continue }
            out.append(Candidate(url: url, modified: modified(url), detail: tr("Points to a missing program")))
        }
        return out
    }

    private static func installers() -> [Candidate] {
        let installerExt: Set<String> = ["dmg", "pkg", "iso", "xip"]
        let partialExt: Set<String> = ["crdownload", "download", "part", "partial"]
        let now = Date()
        return children(of: home.appendingPathComponent("Downloads")).compactMap { url in
            let ext = url.pathExtension.lowercased()
            guard let date = modified(url) else { return nil }
            let age = now.timeIntervalSince(date)
            if installerExt.contains(ext), age > Double(ScanRules.current.installerDays) * 86_400 { return Candidate(url: url, modified: date, detail: lastUse(date)) }
            if partialExt.contains(ext), age > 3 * 86_400 {
                return Candidate(url: url, modified: date, detail: tr("Unfinished download"))
            }
            return nil
        }
    }

    private static func backups() -> [Candidate] {
        let root = library.appendingPathComponent("Application Support/MobileSync/Backup")
        return children(of: root).map { url in
            let info = NSDictionary(contentsOf: url.appendingPathComponent("Info.plist"))
            let device = info?["Device Name"] as? String
            let date = (info?["Last Backup Date"] as? Date) ?? modified(url)
            let detail = [device, date.map(lastUse)].compactMap { $0 }.joined(separator: " · ")
            return Candidate(url: url, modified: date, detail: detail.isEmpty ? nil : detail)
        }
    }

    // MARK: Outils

    private static func children(of dir: URL) -> [URL] {
        (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [])) ?? []
    }

    private static func modified(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private static func lastUse(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: AppLanguage.current.rawValue)
        f.unitsStyle = .full
        return tr("Last modified %@", f.localizedString(for: date, relativeTo: Date()))
    }

    /// macOS refuse l'accès au dossier (confidentialité) : l'utilisateur doit accorder l'accès complet au disque.
    private static func isDenied(_ url: URL) -> Bool {
        do { _ = try fm.contentsOfDirectory(atPath: url.path); return false } catch {
            let e = error as NSError
            return e.domain == NSCocoaErrorDomain && (e.code == NSFileReadNoPermissionError || e.code == NSFileReadUnknownError)
                || e.domain == NSPOSIXErrorDomain && e.code == Int(EPERM)
        }
    }

    private static func runningNames() -> Set<String> {
        var out: Set<String> = []
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier {
                out.insert(InstalledApps.normalize(id))
                let parts = id.split(separator: ".")
                if parts.count >= 2 { out.insert(InstalledApps.normalize(String(parts[1]))) }
            }
            if let name = app.localizedName { out.insert(InstalledApps.normalize(name)) }
        }
        return out
    }

    // MARK: Tailles

    /// Taille réellement occupée sur le disque, mesurée en parallèle (concurrence limitée pour ménager la batterie).
    private static func measure(_ urls: [URL]) -> [Int64] { StorageScan.sizes(urls) }

    /// Taille occupée sur le disque : parcours avec `fts` (bien plus léger que FileManager : pas d'objet URL par fichier).
    static func allocatedSize(of url: URL) -> Int64 {
        guard let path = strdup(url.path) else { return 0 }
        defer { free(path) }
        var argv: [UnsafeMutablePointer<CChar>?] = [path, nil]
        guard let tree = fts_open(&argv, FTS_PHYSICAL | FTS_NOCHDIR | FTS_XDEV, nil) else { return 0 }
        defer { fts_close(tree) }
        var total: Int64 = 0
        while let entry = fts_read(tree) {
            switch Int32(entry.pointee.fts_info) {
            case FTS_F, FTS_D, FTS_SL, FTS_SLNONE, FTS_DEFAULT:
                if let st = entry.pointee.fts_statp { total += Int64(st.pointee.st_blocks) * 512 }
            default: break
            }
        }
        return total
    }
}
