import SwiftUI
import ServiceManagement
import IOKit.ps

/// État d'alimentation du Mac : les analyses automatiques s'effacent sur batterie ou en mode économie d'énergie.
enum Power {
    static var onBattery: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeRetainedValue() as String? else { return false }
        return type == kIOPSBatteryPowerValue
    }
    static var lowPowerMode: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }
}

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
        return .en
    }
}

enum GlassStyle: String, CaseIterable, Identifiable {
    case clear, regular
    var id: String { rawValue }
    var label: String { self == .clear ? tr("Clear") : tr("Regular") }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: tr("System")
        case .light: tr("Light")
        case .dark: tr("Dark")
        }
    }
}

/// Palette du fond coloré (trois teintes) et couleur d'accentuation associée.
enum ThemeChoice: String, CaseIterable, Identifiable {
    case mint, ocean, sunset, violet, graphite
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mint: tr("Mint")
        case .ocean: tr("Ocean")
        case .sunset: tr("Sunset")
        case .violet: tr("Violet")
        case .graphite: tr("Graphite")
        }
    }
    var hues: [Double] {
        switch self {
        case .mint: [0.47, 0.60, 0.38]
        case .ocean: [0.58, 0.64, 0.52]
        case .sunset: [0.02, 0.08, 0.93]
        case .violet: [0.76, 0.68, 0.88]
        case .graphite: [0.58, 0.55, 0.60]
        }
    }
    var saturation: Double { self == .graphite ? 0.10 : 0.55 }
    var accent: Color {
        switch self {
        case .mint: Color(hue: 0.47, saturation: 0.75, brightness: 0.72)
        case .ocean: Color(hue: 0.60, saturation: 0.80, brightness: 0.90)
        case .sunset: Color(hue: 0.03, saturation: 0.75, brightness: 0.95)
        case .violet: Color(hue: 0.76, saturation: 0.60, brightness: 0.90)
        case .graphite: Color(white: 0.45)
        }
    }
}

/// Règles de nettoyage, lues directement dans les préférences (utilisables depuis les threads de fond).
struct ScanRules {
    var tempDays: Int
    var installerDays: Int
    var orphanDays: Int
    var minSizeMB: Int
    var exclusions: [String]
    var disabled: Set<String>

    static var current: ScanRules {
        let d = UserDefaults.standard
        func int(_ key: String, _ fallback: Int) -> Int { d.object(forKey: key) as? Int ?? fallback }
        return ScanRules(tempDays: int("tempDays", 3), installerDays: int("installerDays", 14),
                         orphanDays: int("orphanDays", 30), minSizeMB: int("minSizeMB", 0),
                         exclusions: d.stringArray(forKey: "exclusions") ?? [],
                         disabled: Set(d.stringArray(forKey: "disabledCategories") ?? []))
    }

    func isExcluded(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return exclusions.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}

/// Réglages enregistrés dans UserDefaults.
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let d = UserDefaults.standard

    // Général
    @Published var language: AppLanguage { didSet { d.set(language.rawValue, forKey: "language") } }
    @Published var haptics: Bool { didSet { d.set(haptics, forKey: "haptics") } }
    @Published var autoScan: Bool { didSet { d.set(autoScan, forKey: "autoScan") } }
    @Published var scanHours: Int { didSet { d.set(scanHours, forKey: "scanHours") } }
    /// Pas d'analyse automatique sur batterie (économise l'énergie) ; le bouton d'analyse reste disponible.
    @Published var skipOnBattery: Bool { didSet { d.set(skipOnBattery, forKey: "skipOnBattery") } }
    @Published var confirmBeforeClean: Bool { didSet { d.set(confirmBeforeClean, forKey: "confirmBeforeClean") } }
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

    // Apparence
    @Published var glassStyle: GlassStyle { didSet { d.set(glassStyle.rawValue, forKey: "glassStyle") } }
    /// 0 = verre transparent, 1 = verre dépoli presque opaque.
    @Published var glassFrost: Double { didSet { d.set(glassFrost, forKey: "glassFrost") } }
    @Published var glassTint: Double { didSet { d.set(glassTint, forKey: "glassTint") } }
    @Published var auroraIntensity: Double { didSet { d.set(auroraIntensity, forKey: "auroraIntensity") } }
    @Published var theme: ThemeChoice { didSet { d.set(theme.rawValue, forKey: "theme") } }
    @Published var appearance: AppearanceMode {
        didSet { d.set(appearance.rawValue, forKey: "appearance"); applyAppearance() }
    }

    // Règles de nettoyage (la page Réglages relance une analyse quand elles changent)
    @Published var tempDays: Int { didSet { d.set(tempDays, forKey: "tempDays"); rulesDirty = true } }
    @Published var installerDays: Int { didSet { d.set(installerDays, forKey: "installerDays"); rulesDirty = true } }
    @Published var orphanDays: Int { didSet { d.set(orphanDays, forKey: "orphanDays"); rulesDirty = true } }
    @Published var minSizeMB: Int { didSet { d.set(minSizeMB, forKey: "minSizeMB"); rulesDirty = true } }
    @Published var exclusions: [String] { didSet { d.set(exclusions, forKey: "exclusions"); rulesDirty = true } }
    @Published var disabledCategories: Set<String> {
        didSet { d.set(Array(disabledCategories), forKey: "disabledCategories"); rulesDirty = true }
    }
    var rulesDirty = false

    func isEnabled(_ id: CategoryID) -> Bool { !disabledCategories.contains(id.rawValue) }

    func setEnabled(_ id: CategoryID, _ on: Bool) {
        if on { disabledCategories.remove(id.rawValue) } else { disabledCategories.insert(id.rawValue) }
    }

    func applyAppearance() {
        let value = appearance
        DispatchQueue.main.async {
            switch value {
            case .system: NSApp?.appearance = nil
            case .light: NSApp?.appearance = NSAppearance(named: .aqua)
            case .dark: NSApp?.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }

    func resetAppearance() {
        glassStyle = .regular; glassFrost = 0.15; glassTint = 0.5; auroraIntensity = 0.3; theme = .mint; appearance = .system
    }

    func resetRules() {
        tempDays = 3; installerDays = 14; orphanDays = 30; minSizeMB = 0; exclusions = []; disabledCategories = []
    }

    private init() {
        let d = UserDefaults.standard
        func bool(_ key: String, _ fallback: Bool = true) -> Bool { d.object(forKey: key) as? Bool ?? fallback }
        func int(_ key: String, _ fallback: Int) -> Int { d.object(forKey: key) as? Int ?? fallback }
        func double(_ key: String, _ fallback: Double) -> Double { d.object(forKey: key) as? Double ?? fallback }
        language = AppLanguage.current
        haptics = bool("haptics")
        autoScan = bool("autoScan")
        scanHours = int("scanHours", 3)
        skipOnBattery = bool("skipOnBattery")
        confirmBeforeClean = bool("confirmBeforeClean")
        launchAtLogin = SMAppService.mainApp.status == .enabled
        glassStyle = GlassStyle(rawValue: d.string(forKey: "glassStyle") ?? "") ?? .regular
        glassFrost = double("glassFrost", 0.15)
        glassTint = double("glassTint", 0.5)
        auroraIntensity = double("auroraIntensity", 0.3)
        theme = ThemeChoice(rawValue: d.string(forKey: "theme") ?? "") ?? .mint
        appearance = AppearanceMode(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        let rules = ScanRules.current
        tempDays = rules.tempDays; installerDays = rules.installerDays; orphanDays = rules.orphanDays
        minSizeMB = rules.minSizeMB; exclusions = rules.exclusions; disabledCategories = rules.disabled
    }
}
