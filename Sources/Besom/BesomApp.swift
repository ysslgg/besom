import AppKit
import SwiftUI

@main
struct BesomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var settings = Prefs.shared

    var body: some Scene {
        Window("Besom", id: "main") {
            ContentView(model: delegate.model, storage: delegate.storage)
                .frame(minWidth: 960, minHeight: 640)
                // Changer de langue reconstruit l'interface avec les nouveaux textes.
                .id(settings.language.rawValue)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(tr("Settings…")) { NotificationCenter.default.post(name: .openSettingsPage, object: nil) }
                    .keyboardShortcut(",")
            }
            CommandGroup(after: .newItem) {
                Button(tr("Scan again")) { delegate.model.scan() }
                    .keyboardShortcut("r")
            }
        }
    }
}

func openFullDiskAccess() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = CleanerModel()
    let storage = StorageModel()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `Besom --scan` : affiche ce qui serait nettoyé et quitte, sans rien supprimer.
        if CommandLine.arguments.contains("--scan") {
            let apps = InstalledApps.scan()
            for id in CategoryID.allCases {
                let r = Scanner.scan(id, apps: apps)
                print("\(id.rawValue)\t\(bytes(r.totalSize))\t\(r.items.count) items\(r.needsAccess ? "\tNEEDS ACCESS" : "")")
                for item in r.items.prefix(8) { print("    \(bytes(item.size))\t\(item.url.path)\t\(item.detail ?? "")") }
            }
            exit(0)
        }
        if CommandLine.arguments.contains("--storage") {
            let units = StorageScan.units()
            let box = SizeBox(count: units.count)
            let t0 = Date()
            StorageScan.measure(units) { i, s in box.set(i, s) }
            let sizes = box.values
            let v = StorageScan.volume()
            print("volume \(v.name): total \(bytes(v.total)), free \(bytes(v.free)), measured in \(Int(Date().timeIntervalSince(t0))) s")
            var groups: [StorageGroup: Int64] = [:]
            for (u, s) in zip(units, sizes) { groups[u.group, default: 0] += s }
            for (g, s) in groups.sorted(by: { $0.value > $1.value }) { print("  \(g.rawValue)\t\(bytes(s))") }
            for (u, s) in zip(units, sizes).sorted(by: { $0.1 > $1.1 }).prefix(8) { print("    \(bytes(s))\t\(u.label)") }
            exit(0)
        }
        Prefs.shared.applyAppearance()
        NSApp.setActivationPolicy(.regular)
        // La fenêtre se déplace en la saisissant par son fond (plus de barre de titre).
        DispatchQueue.main.async { NSApp.windows.forEach { $0.isMovableByWindowBackground = true } }
        NSApp.activate(ignoringOtherApps: true)
        model.scan()
        // Rafraîchit de temps en temps si l'app reste ouverte.
        let t = Timer(timeInterval: 1800, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Prefs.shared.autoScan, !self.model.isBusy else { return }
                let age = self.model.lastScan.map { Date().timeIntervalSince($0) } ?? .infinity
                guard age >= Double(Prefs.shared.scanHours) * 3600 - 60 else { return }
                self.model.scan()
                self.storage.refresh()
            }
        }
        t.tolerance = 120
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Tableau de tailles partagé entre les threads de mesure.
final class SizeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var sizes: [Int64]
    init(count: Int) { sizes = [Int64](repeating: 0, count: count) }
    func set(_ i: Int, _ s: Int64) { lock.lock(); sizes[i] = s; lock.unlock() }
    var values: [Int64] { lock.lock(); defer { lock.unlock() }; return sizes }
}
