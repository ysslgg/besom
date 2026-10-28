import SwiftUI

// MARK: - Homebrew

struct HomebrewPage: View {
    @ObservedObject var brew: BrewModel
    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var toRemove: BrewPackage?

    enum Filter: String, CaseIterable, Identifiable {
        case all, formulae, casks, leaves, outdated
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: tr("All")
            case .formulae: tr("Formulae")
            case .casks: tr("Casks")
            case .leaves: tr("Installed by you")
            case .outdated: tr("Outdated")
            }
        }
    }

    private var visible: [BrewPackage] {
        let outdated = Set(brew.updates.map(\.name))
        return brew.packages.filter { p in
            switch filter {
            case .all: true
            case .formulae: !p.isCask
            case .casks: p.isCask
            case .leaves: p.isLeaf && !p.isCask
            case .outdated: outdated.contains(p.name)
            }
        }
        .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        PageScroll {
            PageHeader(title: "Homebrew",
                       subtitle: brew.brewPath == nil ? tr("Homebrew is not installed.")
                                 : tr("%d formulae · %d casks · cache %@", brew.formulaCount, brew.caskCount, bytes(brew.cacheSize)),
                       symbol: "shippingbox.fill", tint: Color(hue: 0.10, saturation: 0.7, brightness: 1.0)) {
                if brew.brewPath != nil {
                    HStack(spacing: 8) {
                        Menu {
                            Button(tr("Update Homebrew index")) { brew.updateIndexOnly() }
                            Button(tr("Clean up downloads and old versions")) { brew.cleanup() }
                            Button(tr("Remove unused dependencies")) { brew.autoremove() }
                        } label: { Label(tr("Maintenance"), systemImage: "wrench.and.screwdriver") }
                            .menuStyle(.button).glassButton().disabled(brew.busy != nil)
                        Button { brew.upgradeAll() } label: {
                            Text(brew.updateCount > 0 ? tr("Update all (%d)", brew.updateCount) : tr("Up to date")).frame(minWidth: 100)
                        }
                        .prominentGlassButton().disabled(brew.busy != nil || brew.updateCount == 0)
                    }
                }
            }

            if let busy = brew.busy {
                HStack(spacing: 10) { ProgressView().controlSize(.small); Text(busy).foregroundStyle(.secondary); Spacer() }
                    .padding(.horizontal, 16).padding(.vertical, 10).glassCard(radius: 16)
            }

            if brew.brewPath == nil && brew.loaded {
                ContentUnavailableView(tr("Homebrew is not installed."), systemImage: "shippingbox",
                                       description: Text(tr("Install it from brew.sh, then come back here.")))
            } else {
                HStack(spacing: 10) {
                    SearchField(text: $query, prompt: tr("Filter packages"))
                    Picker("", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().frame(width: 170)
                }
                LazyVStack(spacing: 4) {
                    ForEach(visible) { pkg in PackageRow(brew: brew, pkg: pkg, toRemove: $toRemove) }
                    if visible.isEmpty && brew.loaded {
                        Text(tr("Nothing to show.")).foregroundStyle(.secondary).padding(20)
                    }
                }
            }
            if !brew.log.isEmpty { LogConsole(lines: brew.log) }
        }
        .onAppear { if !brew.loaded { brew.refresh() } }
        .confirmationDialog(tr("Remove %@?", toRemove?.name ?? ""), isPresented: Binding(get: { toRemove != nil }, set: { if !$0 { toRemove = nil } }),
                            titleVisibility: .visible, presenting: toRemove) { pkg in
            Button(tr("Uninstall"), role: .destructive) { brew.uninstall(pkg) }
            if pkg.isCask { Button(tr("Uninstall and delete its data (zap)"), role: .destructive) { brew.uninstall(pkg, zap: true) } }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { pkg in
            Text(pkg.isCask ? tr("The app is removed from your Mac.") : tr("Other tools that depend on it may stop working."))
        }
    }
}

private struct PackageRow: View {
    @ObservedObject var brew: BrewModel
    let pkg: BrewPackage
    @Binding var toRemove: BrewPackage?

    var body: some View {
        let update = brew.updates.first { $0.name == pkg.name && ($0.source == .cask) == pkg.isCask }
        GlassRow {
            iconBadge(pkg.isCask ? "macwindow" : "terminal", pkg.isCask ? .blue : .orange, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(pkg.name).fontWeight(.medium).lineLimit(1)
                    if pkg.isCask { Pill(text: "Cask", tint: .blue) } else if !pkg.isLeaf { Pill(text: tr("Dependency")) }
                    if update != nil { Pill(text: tr("Update"), tint: .green) }
                }
                Text(update.map { "\($0.from) → \($0.to)" } ?? pkg.version).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if pkg.size > 0 { Text(bytes(pkg.size)).font(.callout.monospacedDigit()).foregroundStyle(.secondary) }
            if let update {
                Button { brew.upgrade(update) } label: { Image(systemName: "arrow.up.circle.fill").foregroundStyle(.green) }
                    .buttonStyle(.plain).disabled(brew.busy != nil).help(tr("Update"))
            }
            Button { toRemove = pkg } label: { Image(systemName: "trash") }
                .buttonStyle(.plain).foregroundStyle(.secondary).disabled(brew.busy != nil).help(tr("Uninstall"))
        }
    }
}

// MARK: - Mises à jour

struct UpdatesPage: View {
    @ObservedObject var brew: BrewModel

    var body: some View {
        PageScroll {
            PageHeader(title: tr("Updates"),
                       subtitle: brew.updateCount == 0 ? tr("Everything is up to date.") : tr("%d updates available", brew.updateCount),
                       symbol: "arrow.triangle.2.circlepath", tint: Color(hue: 0.38, saturation: 0.6, brightness: 0.85)) {
                HStack(spacing: 8) {
                    Button { brew.refresh(updateIndex: true) } label: { Label(tr("Check now"), systemImage: "arrow.clockwise") }
                        .glassButton().disabled(brew.busy != nil)
                    Button { brew.upgradeAll() } label: { Text(tr("Update all")).frame(minWidth: 90) }
                        .prominentGlassButton().disabled(brew.busy != nil || brew.updateCount == 0)
                }
            }
            if let busy = brew.busy {
                HStack(spacing: 10) { ProgressView().controlSize(.small); Text(busy).foregroundStyle(.secondary); Spacer() }
                    .padding(.horizontal, 16).padding(.vertical, 10).glassCard(radius: 16)
            }
            if let last = brew.lastChecked {
                Text(tr("Last checked %@", last.formatted(date: .omitted, time: .shortened)))
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 6)
            }
            group(tr("Homebrew formulae"), .formula)
            group(tr("Homebrew casks"), .cask)
            if brew.masPath != nil {
                group(tr("Mac App Store"), .appStore)
            } else if brew.brewPath != nil {
                GlassRow {
                    iconBadge("bag.fill", .blue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("Mac App Store")).fontWeight(.medium)
                        Text(tr("Install “mas” to update App Store apps from here.")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(tr("Install mas")) { brew.installMas() }.glassButton().disabled(brew.busy != nil)
                }
            }
            GlassRow {
                iconBadge("applelogo", .gray)
                VStack(alignment: .leading, spacing: 1) {
                    Text("macOS").fontWeight(.medium)
                    Text(tr("System updates are handled by macOS.")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(tr("Open Software Update")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension") { NSWorkspace.shared.open(url) }
                }
                .glassButton()
            }
            if !brew.log.isEmpty { LogConsole(lines: brew.log) }
        }
        .onAppear { if !brew.loaded { brew.refresh() } }
    }

    @ViewBuilder private func group(_ title: String, _ source: PackageUpdate.Source) -> some View {
        let items = brew.updates.filter { $0.source == source }
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 10)
                ForEach(items) { u in
                    GlassRow {
                        iconBadge(source == .appStore ? "bag.fill" : (source == .cask ? "macwindow" : "terminal"), source == .formula ? .orange : .blue)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(u.name).fontWeight(.medium)
                            Text("\(u.from) → \(u.to)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(tr("Update")) { brew.upgrade(u) }.glassButton().disabled(brew.busy != nil)
                    }
                }
            }
        }
    }
}
