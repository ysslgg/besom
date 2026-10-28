import SwiftUI
import Charts

func bytes(_ n: Int64) -> String {
    let f = ByteCountFormatter()
    f.countStyle = .file
    f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    return f.string(fromByteCount: n)
}

enum Page: Hashable {
    case overview
    case category(CategoryID)
}

struct ContentView: View {
    @ObservedObject var model: CleanerModel
    @ObservedObject var storage: StorageModel
    @State private var page: Page = {
        // BESOM_PAGE=trash (par exemple) ouvre directement une famille : pratique pour tester l'interface.
        if let raw = ProcessInfo.processInfo.environment["BESOM_PAGE"], let id = CategoryID(rawValue: raw) { return .category(id) }
        return .overview
    }()

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                Section(tr("Storage")) {
                    Label(tr("Overview"), systemImage: "chart.pie.fill").tag(Page.overview)
                }
                Section(tr("Clean")) {
                    ForEach(CategoryID.allCases) { id in
                        SidebarRow(model: model, id: id).tag(Page.category(id))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 290, ideal: 320, max: 380)
        } detail: {
            ZStack(alignment: .bottom) {
                AuroraBackground()
                switch page {
                case .overview: OverviewView(storage: storage, model: model)
                case .category(let id): DetailView(model: model, id: id)
                }
                FooterBar(model: model)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    model.scan()
                    storage.refresh()
                } label: { Label(tr("Scan again"), systemImage: "arrow.clockwise") }
                    .disabled(model.isBusy || storage.phase == .measuring)
                    .help(tr("Scan again"))
            }
        }
        .confirmationDialog(tr("Remove %@?", bytes(model.selectedSize)), isPresented: $model.confirming, titleVisibility: .visible) {
            Button(tr("Clean"), role: .destructive) { model.clean() }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
        .navigationTitle("Besom")
        .onAppear { if storage.phase == .idle { storage.refresh() } }
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

// MARK: - Barre latérale

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

private struct SidebarRow: View {
    @ObservedObject var model: CleanerModel
    let id: CategoryID

    var body: some View {
        let r = model.result(id)
        let empty = r.items.isEmpty
        HStack(spacing: 10) {
            Button { model.toggle(id) } label: { SelectionBox(state: model.state(of: id), tint: id.tint) }
                .buttonStyle(.plain)
                .disabled(empty)
                .opacity(empty ? 0.35 : 1)
            Image(systemName: id.symbol)
                .frame(width: 20)
                .foregroundStyle(empty ? Color.secondary : id.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(id.title).fontWeight(.medium)
                Text(r.needsAccess ? tr("Needs Full Disk Access") : id.subtitle)
                    .font(.caption)
                    .foregroundStyle(r.needsAccess ? Color.orange : Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if model.hasScanned {
                Text(empty ? "—" : bytes(r.totalSize))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(empty ? Color.secondary.opacity(0.5) : Color.primary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.vertical, 3)
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
            .padding(.top, 8)
            .padding(.bottom, 96)
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
            Button { model.confirming = true } label: {
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
                    Text(tr("%d items couldn't be removed (in use or protected).", failed)).font(.caption).foregroundStyle(.orange)
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
