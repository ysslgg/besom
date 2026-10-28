import Foundation

/// Comment un élément est retiré : supprimé pour de bon (données régénérables) ou mis à la corbeille.
enum Disposal {
    case delete
    case trash
}

/// Les familles de fichiers que l'app sait repérer.
enum CategoryID: String, CaseIterable, Identifiable {
    case caches, logs, temp, devCaches, orphans, installers, backups, trash
    var id: String { rawValue }

    var title: String {
        switch self {
        case .caches: tr("App caches")
        case .logs: tr("Logs & crash reports")
        case .temp: tr("Temporary files")
        case .devCaches: tr("Developer leftovers")
        case .orphans: tr("Orphaned app data")
        case .installers: tr("Old installers & partial downloads")
        case .backups: tr("Old device backups")
        case .trash: tr("Trash")
        }
    }

    var subtitle: String {
        switch self {
        case .caches: tr("Rebuilt automatically by your apps")
        case .logs: tr("Diagnostic reports and log files")
        case .temp: tr("Untouched for over 3 days")
        case .devCaches: tr("Xcode build data, npm cache…")
        case .orphans: tr("Left behind by apps you uninstalled")
        case .installers: tr("DMG, PKG, ISO in Downloads, 14+ days old")
        case .backups: tr("iPhone and iPad backups")
        case .trash: tr("Emptied for good")
        }
    }

    var symbol: String {
        switch self {
        case .caches: "internaldrive"
        case .logs: "doc.text"
        case .temp: "clock.arrow.circlepath"
        case .devCaches: "hammer"
        case .orphans: "questionmark.folder"
        case .installers: "shippingbox"
        case .backups: "iphone"
        case .trash: "trash"
        }
    }

    var disposal: Disposal {
        switch self {
        case .caches, .logs, .temp, .devCaches, .trash: .delete
        case .orphans, .installers, .backups: .trash
        }
    }

    /// Cochée d'office : uniquement ce qui se régénère tout seul. Le reste demande un geste volontaire.
    var selectedByDefault: Bool {
        switch self {
        case .caches, .logs, .temp, .devCaches: true
        case .orphans, .installers, .backups, .trash: false
        }
    }

    /// Dossiers dans lesquels l'app a le droit de supprimer (garde-fou appliqué juste avant chaque suppression).
    var allowedRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let lib = home.appendingPathComponent("Library")
        switch self {
        case .caches:
            return [lib.appendingPathComponent("Caches")]
        case .logs:
            return [lib.appendingPathComponent("Logs")]
        case .temp:
            return [URL(fileURLWithPath: NSTemporaryDirectory())]
        case .devCaches:
            return [lib.appendingPathComponent("Developer/Xcode/DerivedData"),
                    lib.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"),
                    lib.appendingPathComponent("Developer/CoreSimulator/Caches"),
                    home.appendingPathComponent(".npm")]
        case .orphans:
            return ["Application Support", "Preferences", "Saved Application State", "HTTPStorages",
                    "WebKit", "LaunchAgents"].map { lib.appendingPathComponent($0) }
        case .installers:
            return [home.appendingPathComponent("Downloads")]
        case .backups:
            return [lib.appendingPathComponent("Application Support/MobileSync/Backup")]
        case .trash:
            return [home.appendingPathComponent(".Trash")]
        }
    }
}

/// Un fichier ou dossier proposé au nettoyage.
struct CleanItem: Identifiable, Hashable {
    let url: URL
    let category: CategoryID
    var size: Int64
    var modified: Date?
    /// Précision affichée sous le nom (ex. « Dernière utilisation il y a 4 mois »).
    var detail: String?

    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

struct CategoryResult: Identifiable {
    let id: CategoryID
    var items: [CleanItem] = []
    /// L'accès au dossier est refusé par macOS : il faut l'accès complet au disque.
    var needsAccess = false

    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}
