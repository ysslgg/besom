import AppKit

/// Inventaire des apps présentes sur le Mac, pour reconnaître les données qui n'appartiennent plus à personne.
struct InstalledApps {
    private(set) var bundleIDs: Set<String> = []
    /// Noms d'apps, d'exécutables et de fournisseurs, en minuscules sans ponctuation.
    private(set) var names: Set<String> = []
    /// « com.google », « org.mozilla »… (deux premiers éléments des identifiants).
    private(set) var vendors: Set<String> = []

    static func normalize(_ s: String) -> String {
        s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    mutating func add(bundleID: String) {
        let id = bundleID.lowercased()
        guard !id.isEmpty else { return }
        bundleIDs.insert(id)
        let parts = id.split(separator: ".")
        if parts.count >= 2 {
            vendors.insert(parts.prefix(2).joined(separator: "."))
            names.insert(Self.normalize(String(parts[1])))
        }
        if let last = parts.last { names.insert(Self.normalize(String(last))) }
    }

    mutating func add(name: String) {
        let n = Self.normalize(name)
        if !n.isEmpty { names.insert(n) }
    }

    /// Construit l'inventaire : Spotlight pour trouver toutes les apps, puis les dossiers habituels en renfort.
    static func scan() -> InstalledApps {
        var apps = InstalledApps()
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        var paths = Set(spotlightApps())
        let roots = ["/Applications", "/Applications/Utilities", "/System/Applications",
                     "/System/Applications/Utilities", home.appendingPathComponent("Applications").path]
        for root in roots {
            for name in (try? fm.contentsOfDirectory(atPath: root)) ?? [] {
                let full = root + "/" + name
                if name.hasSuffix(".app") {
                    paths.insert(full)
                } else {
                    // Dossiers d'éditeur (Adobe, Microsoft…) : un niveau de plus.
                    for sub in (try? fm.contentsOfDirectory(atPath: full)) ?? [] where sub.hasSuffix(".app") {
                        paths.insert(full + "/" + sub)
                    }
                }
            }
        }
        for path in paths { apps.addApp(at: path) }

        // Apps en cours d'exécution (y compris celles lancées hors des dossiers habituels).
        for app in NSWorkspace.shared.runningApplications {
            if let id = app.bundleIdentifier { apps.add(bundleID: id) }
            if let name = app.localizedName { apps.add(name: name) }
            if let exe = app.executableURL?.lastPathComponent { apps.add(name: exe) }
        }

        // Outils système, outils en ligne de commande et casks Homebrew : leurs réglages vivent dans Library aussi.
        let binDirs = ["/usr/libexec", "/usr/sbin", "/usr/bin", "/System/Library/CoreServices",
                       "/System/Library/CoreServices/Applications", "/opt/homebrew/bin", "/usr/local/bin", "/opt/homebrew/Caskroom", "/usr/local/Caskroom",
                       home.appendingPathComponent(".local/bin").path, home.appendingPathComponent(".cargo/bin").path]
        for dir in binDirs {
            for name in (try? fm.contentsOfDirectory(atPath: dir)) ?? [] { apps.add(name: name) }
        }

        // Services installés avec les apps (agents, daemons, helpers privilégiés) : leur identifiant désigne l'éditeur.
        let serviceDirs = ["/Library/LaunchAgents", "/Library/LaunchDaemons", "/Library/PrivilegedHelperTools",
                           "/Library/Application Support", "/Library/Preferences"]
        for dir in serviceDirs {
            for name in (try? fm.contentsOfDirectory(atPath: dir)) ?? [] {
                let base = name.hasSuffix(".plist") ? String(name.dropLast(6)) : name
                if base.contains(".") { apps.add(bundleID: base) } else { apps.add(name: base) }
            }
        }
        return apps
    }

    private mutating func addApp(at path: String) {
        let url = URL(fileURLWithPath: path)
        add(name: url.deletingPathExtension().lastPathComponent)
        guard let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) else { return }
        if let id = info["CFBundleIdentifier"] as? String { add(bundleID: id) }
        for key in ["CFBundleName", "CFBundleDisplayName", "CFBundleExecutable"] {
            if let v = info[key] as? String { add(name: v) }
        }
    }

    private static func spotlightApps() -> [String] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        p.arguments = ["kMDItemContentTypeTree == 'com.apple.application-bundle'"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (String(data: data, encoding: .utf8) ?? "").split(separator: "\n").map(String.init)
    }

    /// Vrai si ce nom de dossier / fichier (réglage, cache…) correspond à une app ou un outil installé.
    func owns(_ rawName: String) -> Bool {
        var name = rawName.lowercased()
        for ext in [".plist", ".savedstate", ".binarycookies", ".lockfile"] where name.hasSuffix(ext) {
            name = String(name.dropLast(ext.count))
        }
        if bundleIDs.contains(name) { return true }
        // « com.foo.app.helper » appartient à « com.foo.app », et inversement.
        for id in bundleIDs where name.hasPrefix(id + ".") || id.hasPrefix(name + ".") { return true }
        let parts = name.split(separator: ".")
        if parts.count >= 2, vendors.contains(parts.prefix(2).joined(separator: ".")) { return true }
        let flat = Self.normalize(name)
        if names.contains(flat) { return true }
        // Nom d'éditeur seul (« Google », « Mozilla »…).
        if vendors.contains(where: { $0.hasSuffix("." + name) }) { return true }
        return false
    }
}
