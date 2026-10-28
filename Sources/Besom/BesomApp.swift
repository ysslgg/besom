import AppKit
import SwiftUI

@main
struct BesomApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var settings = Prefs.shared

    var body: some Scene {
        Window("Besom", id: "main") {
            ContentView(model: delegate.model)
                .frame(minWidth: 780, minHeight: 520)
                // Changer de langue reconstruit l'interface avec les nouveaux textes.
                .id(settings.language.rawValue)
        }
        .defaultSize(width: 900, height: 620)
        .commands {
            CommandGroup(after: .newItem) {
                Button(tr("Scan again")) { delegate.model.scan() }
                    .keyboardShortcut("r")
            }
        }

        Settings {
            SettingsView().id(settings.language.rawValue)
        }
    }
}

private struct SettingsView: View {
    @ObservedObject private var settings = Prefs.shared

    var body: some View {
        Form {
            Toggle(tr("Scan automatically"), isOn: $settings.autoScan)
            Toggle(tr("Haptic feedback"), isOn: $settings.haptics)
            Toggle(tr("Launch at login"), isOn: $settings.launchAtLogin)
            Picker(tr("Language"), selection: $settings.language) {
                ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
            }
            Button(tr("Open Full Disk Access settings…")) { openFullDiskAccess() }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 250)
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
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        model.scan()
        // Rafraîchit de temps en temps si l'app reste ouverte.
        let t = Timer(timeInterval: 3 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let model = self?.model, Prefs.shared.autoScan, !model.isBusy else { return }
                model.scan()
            }
        }
        t.tolerance = 600
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
