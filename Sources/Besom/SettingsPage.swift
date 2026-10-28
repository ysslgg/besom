import SwiftUI

extension Notification.Name {
    static let openSettingsPage = Notification.Name("besom.openSettingsPage")
}

/// Onglet Réglages : apparence (dont la transparence du verre), règles de nettoyage, exclusions, général.
struct SettingsPage: View {
    @ObservedObject private var prefs = Prefs.shared
    @ObservedObject private var updater = AppUpdater.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Settings")).font(.largeTitle.weight(.bold))
                    Text(tr("Make Besom look and behave the way you like.")).foregroundStyle(.secondary)
                }
                appearance
                rules
                families
                exclusions
                general
                about
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Apparence

    private var appearance: some View {
        SettingsCard(title: tr("Appearance"), symbol: "paintpalette.fill") {
            SettingRow(title: tr("Theme")) {
                HStack(spacing: 10) {
                    ForEach(ThemeChoice.allCases) { t in
                        Button { prefs.theme = t } label: {
                            Circle()
                                .fill(LinearGradient(colors: [Color(hue: t.hues[0], saturation: t.saturation + 0.1, brightness: 0.95),
                                                              Color(hue: t.hues[1], saturation: t.saturation, brightness: 0.85)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(.white.opacity(prefs.theme == t ? 0.95 : 0.25), lineWidth: prefs.theme == t ? 2.5 : 1))
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .help(t.label)
                    }
                }
            }
            SettingRow(title: tr("Appearance")) {
                Picker("", selection: $prefs.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 230)
            }
            SettingRow(title: tr("Glass style"), subtitle: tr("Clear shows more of the background; Regular is a little more frosted.")) {
                Picker("", selection: $prefs.glassStyle) {
                    ForEach(GlassStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 180)
            }
            SettingRow(title: tr("Glass transparency"), subtitle: tr("Left: frosted and opaque. Right: fully see-through.")) {
                SliderValue(value: Binding(get: { 1 - prefs.glassFrost }, set: { prefs.glassFrost = 1 - $0 }))
            }
            SettingRow(title: tr("Glass tint"), subtitle: tr("How strongly cards pick up their accent color.")) {
                SliderValue(value: $prefs.glassTint)
            }
            SettingRow(title: tr("Background color"), subtitle: tr("Lower it for a calmer, more neutral window.")) {
                SliderValue(value: $prefs.auroraIntensity)
            }
            HStack {
                Spacer()
                Button(tr("Reset appearance")) { prefs.resetAppearance() }.glassButton()
            }
        }
    }

    // MARK: Règles

    private var rules: some View {
        SettingsCard(title: tr("Cleaning rules"), symbol: "slider.horizontal.3") {
            SettingRow(title: tr("Temporary files"), subtitle: tr("Only those untouched for at least…")) {
                DayPicker(value: $prefs.tempDays, options: [1, 3, 7, 14])
            }
            SettingRow(title: tr("Old installers"), subtitle: tr("DMG, PKG, ISO in Downloads older than…")) {
                DayPicker(value: $prefs.installerDays, options: [7, 14, 30, 60])
            }
            SettingRow(title: tr("Orphaned data protection"), subtitle: tr("Never suggest anything modified more recently than…")) {
                DayPicker(value: $prefs.orphanDays, options: [7, 30, 90])
            }
            SettingRow(title: tr("Hide small items"), subtitle: tr("Skip items smaller than…")) {
                Picker("", selection: $prefs.minSizeMB) {
                    Text(tr("Show all")).tag(0)
                    ForEach([1, 10, 100], id: \.self) { Text("\($0) MB").tag($0) }
                }
                .labelsHidden().frame(width: 130)
            }
            HStack {
                Text(tr("Changes apply at the next scan, which starts when you leave this tab."))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(tr("Reset rules")) { prefs.resetRules() }.glassButton()
            }
        }
    }

    private var families: some View {
        SettingsCard(title: tr("Families to scan"), symbol: "checklist") {
            ForEach(CategoryID.allCases) { id in
                SettingRow(title: id.title, subtitle: id.subtitle) {
                    Toggle("", isOn: Binding(get: { prefs.isEnabled(id) }, set: { prefs.setEnabled(id, $0) }))
                        .toggleStyle(.switch).labelsHidden()
                }
            }
        }
    }

    private var exclusions: some View {
        SettingsCard(title: tr("Never touch these folders"), symbol: "hand.raised.fill") {
            if prefs.exclusions.isEmpty {
                Text(tr("No exclusions. Anything you add here is never listed or removed."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(prefs.exclusions, id: \.self) { path in
                HStack {
                    Image(systemName: "folder.fill").foregroundStyle(.secondary)
                    Text(path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button { prefs.exclusions.removeAll { $0 == path } } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.primary.opacity(0.06)))
            }
            HStack {
                Spacer()
                Button(tr("Add folder…")) { addExclusion() }.glassButton()
            }
        }
    }

    private func addExclusion() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.prompt = tr("Exclude")
        if panel.runModal() == .OK {
            for url in panel.urls where !prefs.exclusions.contains(url.standardizedFileURL.path) {
                prefs.exclusions.append(url.standardizedFileURL.path)
            }
        }
    }

    // MARK: Général

    private var general: some View {
        SettingsCard(title: tr("General"), symbol: "gearshape.fill") {
            SettingRow(title: tr("Scan automatically")) {
                Toggle("", isOn: $prefs.autoScan).toggleStyle(.switch).labelsHidden()
            }
            if prefs.autoScan {
                SettingRow(title: tr("Scan every")) {
                    Picker("", selection: $prefs.scanHours) {
                        ForEach([1, 3, 6, 12, 24], id: \.self) { Text(tr("%d h", $0)).tag($0) }
                    }
                    .labelsHidden().frame(width: 110)
                }
            }
            SettingRow(title: tr("Pause automatic scans on battery"), subtitle: tr("Saves energy. Also paused in Low Power Mode. You can still scan by hand.")) {
                Toggle("", isOn: $prefs.skipOnBattery).toggleStyle(.switch).labelsHidden()
            }
            SettingRow(title: tr("Ask before cleaning"), subtitle: tr("Shows a confirmation with what is deleted and what goes to the Trash.")) {
                Toggle("", isOn: $prefs.confirmBeforeClean).toggleStyle(.switch).labelsHidden()
            }
            SettingRow(title: tr("Haptic feedback")) {
                Toggle("", isOn: $prefs.haptics).toggleStyle(.switch).labelsHidden()
            }
            SettingRow(title: tr("Launch at login")) {
                Toggle("", isOn: $prefs.launchAtLogin).toggleStyle(.switch).labelsHidden()
            }
            SettingRow(title: tr("Language")) {
                Picker("", selection: $prefs.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().frame(width: 140)
            }
        }
    }

    private var updateSubtitle: String {
        switch updater.state {
        case .idle: return tr("Checks GitHub for a newer version once a day.")
        case .checking: return tr("Checking…")
        case .upToDate: return tr("You have the latest version.")
        case .available(let v, _): return tr("Version %@ is available.", v)
        case .failed: return tr("Could not check for updates.")
        }
    }

    private var about: some View {
        SettingsCard(title: tr("Access"), symbol: "lock.shield.fill") {
            SettingRow(title: tr("Full Disk Access"), subtitle: tr("Needed to read the Trash, device backups and protected app data.")) {
                Button(tr("Open settings")) { openFullDiskAccess() }.glassButton()
            }
            SettingRow(title: tr("Besom %@", AppUpdater.current), subtitle: updateSubtitle) {
                if updater.availableVersion != nil {
                    Button(tr("Download")) { updater.openDownload() }.prominentGlassButton()
                } else {
                    Button(tr("Check for updates")) { updater.check() }.glassButton().disabled(updater.state == .checking)
                }
            }
        }
    }
}

// MARK: - Composants

private struct SettingsCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.headline)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

private struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 12)
            control()
        }
    }
}

private struct SliderValue: View {
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: $value, in: 0...1).frame(width: 190)
            Text("\(Int((value * 100).rounded())) %").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
        }
    }
}

private struct DayPicker: View {
    @Binding var value: Int
    let options: [Int]

    var body: some View {
        Picker("", selection: $value) {
            ForEach(Set(options + [value]).sorted(), id: \.self) { Text(tr("%d days", $0)).tag($0) }
        }
        .labelsHidden().frame(width: 130)
    }
}
