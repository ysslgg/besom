import SwiftUI
import ServiceManagement

/// Langues de l'interface : celle du système au premier lancement (français ou anglais), modifiable ensuite.
enum AppLanguage: String, CaseIterable, Identifiable {
    case en, fr
    var id: String { rawValue }
    var label: String {
        switch self {
        case .en: "English"
        case .fr: "Français"
        }
    }

    /// Lue directement dans les préférences : utilisable depuis n'importe quel thread.
    static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: "language"), let l = AppLanguage(rawValue: raw) { return l }
        return Locale.preferredLanguages.first?.hasPrefix("fr") == true ? .fr : .en
    }
}

/// Réglages enregistrés dans UserDefaults.
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    @Published var language: AppLanguage { didSet { d.set(language.rawValue, forKey: "language") } }
    @Published var haptics: Bool { didSet { d.set(haptics, forKey: "haptics") } }
    /// Analyse au lancement puis toutes les quelques heures.
    @Published var autoScan: Bool { didSet { d.set(autoScan, forKey: "autoScan") } }
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Besom: could not change launch at login: \(error)")
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private init() {
        let d = UserDefaults.standard
        func bool(_ key: String, _ fallback: Bool = true) -> Bool { d.object(forKey: key) as? Bool ?? fallback }
        language = AppLanguage.current
        haptics = bool("haptics")
        autoScan = bool("autoScan")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
