import Foundation

struct RemovalReport {
    /// Octets réellement libérés (suppression définitive).
    var freed: Int64 = 0
    /// Octets mis à la corbeille : ils ne se libèrent qu'au vidage de la corbeille.
    var trashed: Int64 = 0
    var removed = 0
    var failed = 0
    var refused = 0
    /// Éléments refusés faute de droits (ex. dossiers appartenant à root) : récupérables avec un mot de passe administrateur.
    var needsAdmin: [CleanItem] = []
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
                if isPermissionError(error) { report.needsAdmin.append(item) }
                NSLog("Besom: could not remove \(item.url.path): \(error.localizedDescription)")
            }
        }
        progress(items.count, items.count)
        return report
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain, ns.code == NSFileWriteNoPermissionError || ns.code == NSFileReadNoPermissionError { return true }
        if ns.domain == NSPOSIXErrorDomain, ns.code == Int(EACCES) || ns.code == Int(EPERM) { return true }
        if let under = ns.userInfo[NSUnderlyingErrorKey] as? Error { return isPermissionError(under) }
        return false
    }

    /// Exécute osascript et renvoie le message d'erreur éventuel (nil si tout s'est bien passé).
    private static func runAppleScript(_ source: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        let err = Pipe()
        p.standardOutput = FileHandle.nullDevice
        p.standardError = err
        do { try p.run() } catch { return error.localizedDescription }
        let data = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus != 0 else { return nil }
        let text = (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "osascript exit \(p.terminationStatus)" : text
    }

    /// Vide la Corbeille avec le Finder : c'est lui qui demande le mot de passe pour les dossiers appartenant à root,
    /// comme un « Vider la corbeille » fait à la main.
    static func emptyTrashViaFinder() -> String? {
        runAppleScript("with timeout of 7200 seconds\ntell application \"Finder\" to empty trash\nend timeout")
    }

    /// Suppression avec les droits administrateur (macOS demande le mot de passe lui-même).
    /// Seuls les éléments qui passent le garde-fou sont transmis, chacun avec son chemin exact.
    static func removeAsAdmin(_ items: [CleanItem]) -> String? {
        let safe = items.filter(isAllowed)
        guard !safe.isEmpty else { return nil }
        for chunk in stride(from: 0, to: safe.count, by: 40).map({ Array(safe[$0..<min($0 + 40, safe.count)]) }) {
            let args = chunk.map { "'" + $0.url.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }.joined(separator: " ")
            let shell = "/bin/rm -rf -- " + args
            let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            if let error = runAppleScript("do shell script \"\(escaped)\" with administrator privileges") { return error }
        }
        return nil
    }
}
