import SwiftUI
import Charts

func bytes(_ n: Int64) -> String {
    let f = ByteCountFormatter()
    f.countStyle = .file
    f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    return f.string(fromByteCount: n)
}

enum Page: Hashable {
    var isCategory: Bool { if case .category = self { true } else { false } }
    case overview
    case settings
    case homebrew
    case updates
    case category(CategoryID)
}

struct ContentView: View {
    @ObservedObject var model: CleanerModel
    @ObservedObject var storage: StorageModel
    @ObservedObject var brew: BrewModel
    @ObservedObject private var prefs = Prefs.shared
    @State private var page: Page = {
        // BESOM_PAGE=trash (par exemple) ouvre directement une famille : pratique pour tester l'interface.
        switch ProcessInfo.processInfo.environment["BESOM_PAGE"] {
        case "settings": return .settings
        case "homebrew": return .homebrew
        case "updates": return .updates
        default: break
        }
        if let raw = ProcessInfo.processInfo.environment["BESOM_PAGE"], let id = CategoryID(rawValue: raw) { return .category(id) }
        return .overview
    }()

    var body: some View {
        ZStack {
            AuroraBackground()
            HStack(spacing: 0) {
                Sidebar(model: model, storage: storage, brew: brew, page: $page)
                ZStack(alignment: .bottom) {
                    Group {
                        switch page {
                        case .overview: OverviewView(storage: storage, model: model)
                        case .settings: SettingsPage()
                        case .homebrew: HomebrewPage(brew: brew)
                        case .updates: UpdatesPage(brew: brew)
                        case .category(let id): DetailView(model: model, id: id)
                        }
                    }
                    // Le contenu s'efface en douceur sous la barre flottante.
                    .mask {
                        VStack(spacing: 0) {
                            Rectangle()
                            if page == .overview || page.isCategory {
                                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 96)
                            }
                        }
                    }
                    if page == .overview || page.isCategory {
                        FooterBar(model: model)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 16)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .confirmationDialog(tr("Remove %@?", bytes(model.selectedSize)), isPresented: $model.confirming, titleVisibility: .visible) {
            Button(tr("Clean"), role: .destructive) { model.clean() }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
        .tint(prefs.theme.accent)
        .onAppear { storage.refreshIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsPage)) { _ in page = .settings }
        // Quand on quitte les Réglages après avoir changé une règle, on relance l'analyse.
        .onChange(of: page) { old, _ in
            if old == .settings, prefs.rulesDirty {
                prefs.rulesDirty = false
                model.scan()
            }
        }
    }

    private var confirmationMessage: String {
        let items = model.results.flatMap(\.items).filter { model.selected.contains($0.id) }
        let trash = items.filter { $0.category.disposal == .trash }.reduce(Int64(0)) { $0 + $1.size }
        let gone = items.filter { $0.category.disposal == .delete }.reduce(Int64(0)) { $0 + $1.size }
        var lines: [String] = []
        if gone > 0 { lines.append(tr("%@ will be deleted for good.", bytes(gone))) }
        if trash > 0 { lines.append(tr("%@ will be moved to the Trash.", bytes(trash))) }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Barre latérale en verre

private struct SelectionBox: View {
    let state: CleanerModel.Tri
    var tint: Color = .accentColor
    var body: some View {
        Image(systemName: state == .all ? "checkmark.circle.fill" : (state == .some ? "minus.circle.fill" : "circle"))
            .font(.system(size: 17))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(state == .none ? Color.secondary : tint)
    }
}

private struct Sidebar: View {
    @ObservedObject var model: CleanerModel
    @ObservedObject var storage: StorageModel
    @ObservedObject var brew: BrewModel
    @Binding var page: Page
    @ObservedObject private var updater = AppUpdater.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 34, height: 34)
                Text("Besom").font(.title3.weight(.bold))
                Spacer()
                Button {
                    model.scan()
                    storage.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 13, weight: .semibold)).frame(width: 30, height: 30)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .glassCapsule()
                .disabled(model.isBusy || storage.phase == .measuring)
                .opacity(model.isBusy || storage.phase == .measuring ? 0.4 : 1)
                .help(tr("Scan again"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 50)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    sectionTitle(tr("Storage"))
                    NavRow(selected: page == .overview, tint: .accentColor) { page = .overview } content: {
                        iconBadge("chart.pie.fill", .accentColor)
                        Text(tr("Overview")).fontWeight(.medium)
                        Spacer()
                    }
                    sectionTitle(tr("Manage")).padding(.top, 10)
                    NavRow(selected: page == .homebrew, tint: .orange) { page = .homebrew } content: {
                        iconBadge("shippingbox.fill", .orange)
                        Text("Homebrew").fontWeight(.medium)
                        Spacer()
                    }
                    NavRow(selected: page == .updates, tint: .green) { page = .updates } content: {
                        iconBadge("arrow.triangle.2.circlepath", .green)
                        Text(tr("Updates")).fontWeight(.medium)
                        Spacer()
                        if brew.updateCount > 0 { Pill(text: "\(brew.updateCount)", tint: .green) }
                    }
                    sectionTitle(tr("Clean")).padding(.top, 10)
                    ForEach(CategoryID.allCases) { id in
                        CategoryNavRow(model: model, id: id, selected: page == .category(id)) { page = .category(id) }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)

            NavRow(selected: page == .settings, tint: .accentColor) { page = .settings } content: {
                iconBadge("gearshape.fill", .accentColor)
                Text(tr("Settings")).fontWeight(.medium)
                Spacer()
                if updater.availableVersion != nil { Pill(text: tr("Update"), tint: .green) }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .frame(width: 318)
        .frame(maxHeight: .infinity)
        // Panneau plus clair que le reste : un voile blanc sous le verre.
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(scheme == .dark ? 0.16 : 0.38)))
        .glassCard(radius: 30)
        .padding(.leading, 10).padding(.vertical, 10).padding(.trailing, 4)
    }

    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.top, 2)
    }
}

private func iconBadge(_ symbol: String, _ tint: Color, dimmed: Bool = false) -> some View {
    Image(systemName: symbol)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(dimmed ? Color.secondary : tint)
        .frame(width: 30, height: 30)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill((dimmed ? Color.secondary : tint).opacity(0.16)))
}

private struct NavRow<Content: View>: View {
    let selected: Bool
    let tint: Color
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) { content() }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(selected ? tint.opacity(0.22) : Color.primary.opacity(hovering ? 0.07 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(selected ? tint.opacity(0.45) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.15), value: selected)
    }
}

private struct CategoryNavRow: View {
    @ObservedObject var model: CleanerModel
    let id: CategoryID
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let r = model.result(id)
        let empty = r.items.isEmpty
        let disabled = !Prefs.shared.isEnabled(id)
        NavRow(selected: selected, tint: id.tint, action: action) {
            iconBadge(id.symbol, id.tint, dimmed: empty)
            VStack(alignment: .leading, spacing: 1) {
                Text(id.title).fontWeight(.medium).lineLimit(1)
                Text(disabled ? tr("Turned off in Settings") : (r.needsAccess ? tr("Needs Full Disk Access") : id.subtitle))
                    .font(.caption)
                    .foregroundStyle(r.needsAccess && !disabled ? Color.orange : Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if model.hasScanned {
                Text(empty ? "—" : bytes(r.totalSize))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(empty ? Color.secondary.opacity(0.5) : Color.primary)
                    .lineLimit(1).fixedSize()
            } else {
                ProgressView().controlSize(.small)
            }
            Button { model.toggle(id) } label: { SelectionBox(state: model.state(of: id), tint: id.tint) }
                .buttonStyle(.plain)
                .disabled(empty)
                .opacity(empty ? 0.25 : 1)
        }
    }
}

// MARK: - Détail d'une famille

private struct DetailView: View {
    @ObservedObject var model: CleanerModel
    let id: CategoryID

    var body: some View {
        let r = model.result(id)
        ScrollView {
            VStack(spacing: 16) {
                header(r)
                if r.items.isEmpty {
                    empty(r).padding(.top, 20)
                } else {
                    if r.items.count > 1 { chart(r) }
                    VStack(spacing: 4) {
                        ForEach(r.items.prefix(300)) { ItemRow(model: model, item: $0, tint: id.tint) }
                        if r.items.count > 300 {
                            Text(tr("+ %d smaller items", r.items.count - 300)).foregroundStyle(.secondary).padding(8)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    private func header(_ r: CategoryResult) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: id.symbol)
                .font(.system(size: 26))
                .foregroundStyle(id.tint)
                .frame(width: 52, height: 52)
                .glassCard(radius: 16, tint: id.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(id.title).font(.title2.weight(.semibold))
                Text(id.disposal == .trash
                     ? tr("Moved to the Trash, so you can still get them back.")
                     : tr("Removed for good. These files are recreated when needed."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(bytes(r.totalSize)).font(.title2.weight(.bold).monospacedDigit())
                if !r.items.isEmpty {
                    Button(model.state(of: id) == .all ? tr("Deselect all") : tr("Select all")) { model.toggle(id) }
                        .buttonStyle(.link)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    /// Les éléments les plus lourds, d'un coup d'œil.
    private func chart(_ r: CategoryResult) -> some View {
        let top = Array(r.items.prefix(6))
        return VStack(alignment: .leading, spacing: 8) {
            Text(tr("Biggest items")).font(.headline)
            Chart(top) { item in
                BarMark(x: .value("Size", item.size), y: .value("Item", item.name))
                    .cornerRadius(5)
                    .foregroundStyle(LinearGradient(colors: [id.tint, id.tint.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .opacity(model.selected.contains(item.id) ? 1 : 0.35)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text(bytes(item.size)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
            }
            .chartYScale(domain: top.map(\.name))
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { _ in AxisValueLabel(horizontalSpacing: 8).font(.caption) }
            }
            .chartXScale(range: .plotDimension(endPadding: 64))
            .frame(height: CGFloat(top.count) * 28 + 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    @ViewBuilder private func empty(_ r: CategoryResult) -> some View {
        if r.needsAccess {
            ContentUnavailableView {
                Label(tr("Needs Full Disk Access"), systemImage: "lock")
            } description: {
                Text(tr("macOS keeps this folder private. Allow Besom in System Settings → Privacy & Security → Full Disk Access, then scan again."))
            } actions: {
                Button(tr("Open settings")) { openFullDiskAccess() }.glassButton()
            }
        } else if model.hasScanned {
            ContentUnavailableView(tr("Nothing to clean here"), systemImage: "checkmark.circle")
        } else {
            ProgressView(tr("Scanning…")).frame(maxWidth: .infinity, minHeight: 200)
        }
    }
}

private struct ItemRow: View {
    @ObservedObject var model: CleanerModel
    let item: CleanItem
    let tint: Color
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button { model.toggle(item) } label: {
                SelectionBox(state: model.selected.contains(item.id) ? .all : .none, tint: tint)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).lineLimit(1).truncationMode(.middle)
                Text([item.detail, item.url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~")]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .opacity(hovering ? 1 : 0.35)
            .help(tr("Show in Finder"))
            Text(bytes(item.size)).font(.callout.monospacedDigit()).frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.primary.opacity(hovering ? 0.09 : 0.05)))
        .onHover { hovering = $0 }
    }
}

// MARK: - Barre flottante

private struct FooterBar: View {
    @ObservedObject var model: CleanerModel

    var body: some View {
        HStack(spacing: 14) {
            status
            Spacer()
            Button { if Prefs.shared.confirmBeforeClean { model.confirming = true } else { model.clean() } } label: {
                Text(tr("Clean %@", bytes(model.selectedSize))).fontWeight(.semibold).frame(minWidth: 120)
            }
            .prominentGlassButton()
            .controlSize(.large)
            .disabled(model.selectedSize == 0 || model.isBusy)
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .glassCapsule()
        .frame(maxWidth: 640)
    }

    @ViewBuilder private var status: some View {
        switch model.phase {
        case .scanning:
            HStack(spacing: 8) { ProgressView().controlSize(.small); Text(tr("Scanning…")).foregroundStyle(.secondary) }
        case .cleaning(let done, let total):
            HStack(spacing: 10) {
                ProgressView(value: Double(done), total: Double(max(total, 1))).frame(width: 160)
                Text(tr("Cleaning… %d / %d", done, total)).foregroundStyle(.secondary)
            }
        case .done(let freed, let trashed, let failed):
            VStack(alignment: .leading, spacing: 2) {
                Text(summary(freed: freed, trashed: trashed)).fontWeight(.semibold).foregroundStyle(.green)
                if failed > 0 {
                    Text(tr("%d items couldn't be removed (in use, protected or owned by another user).", failed)).font(.caption).foregroundStyle(.orange)
                }
                if let reason = model.adminError {
                    Text(reason).font(.caption2).foregroundStyle(.red.opacity(0.9)).lineLimit(3).textSelection(.enabled)
                }
            }
        case .idle:
            Text(tr("%@ selected · %@ found", bytes(model.selectedSize), bytes(model.totalSize))).foregroundStyle(.secondary)
        }
    }

    private func summary(freed: Int64, trashed: Int64) -> String {
        switch (freed > 0, trashed > 0) {
        case (true, true): tr("%@ freed · %@ moved to the Trash", bytes(freed), bytes(trashed))
        case (true, false): tr("%@ freed ✓", bytes(freed))
        case (false, true): tr("%@ moved to the Trash", bytes(trashed))
        default: tr("Nothing was removed")
        }
    }
}
