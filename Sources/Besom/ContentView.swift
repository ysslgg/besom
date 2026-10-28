import SwiftUI

func bytes(_ n: Int64) -> String {
    let f = ByteCountFormatter()
    f.countStyle = .file
    f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
    return f.string(fromByteCount: n)
}

struct ContentView: View {
    @ObservedObject var model: CleanerModel
    @State private var current: CategoryID = .caches

    var body: some View {
        NavigationSplitView {
            List(CategoryID.allCases, selection: $current) { id in
                SidebarRow(model: model, id: id).tag(id)
            }
            .navigationSplitViewColumnWidth(min: 290, ideal: 320, max: 380)
        } detail: {
            DetailView(model: model, id: current)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { FooterBar(model: model) }
        .toolbar {
            ToolbarItem {
                Button { model.scan() } label: { Label(tr("Scan again"), systemImage: "arrow.clockwise") }
                    .disabled(model.isBusy)
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
    var body: some View {
        Image(systemName: state == .all ? "checkmark.square.fill" : (state == .some ? "minus.square.fill" : "square"))
            .font(.system(size: 16))
            .foregroundStyle(state == .none ? Color.secondary : Color.accentColor)
    }
}

private struct SidebarRow: View {
    @ObservedObject var model: CleanerModel
    let id: CategoryID

    var body: some View {
        let r = model.result(id)
        let empty = r.items.isEmpty
        HStack(spacing: 10) {
            Button { model.toggle(id) } label: { SelectionBox(state: model.state(of: id)) }
                .buttonStyle(.plain)
                .disabled(empty)
                .opacity(empty ? 0.35 : 1)
            Image(systemName: id.symbol)
                .frame(width: 20)
                .foregroundStyle(empty ? Color.secondary : Color.accentColor)
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

// MARK: - Détail

private struct DetailView: View {
    @ObservedObject var model: CleanerModel
    let id: CategoryID

    var body: some View {
        let r = model.result(id)
        VStack(spacing: 0) {
            header(r)
            Divider()
            if r.items.isEmpty {
                empty(r)
            } else {
                List {
                    ForEach(r.items.prefix(300)) { ItemRow(model: model, item: $0) }
                    if r.items.count > 300 {
                        Text(tr("+ %d smaller items", r.items.count - 300)).foregroundStyle(.secondary)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func header(_ r: CategoryResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: id.symbol).font(.system(size: 26)).foregroundStyle(Color.accentColor).frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(id.title).font(.title2.weight(.semibold))
                Text(id.disposal == .trash
                     ? tr("Moved to the Trash, so you can still get them back.")
                     : tr("Removed for good. These files are recreated when needed."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(bytes(r.totalSize)).font(.title3.weight(.semibold).monospacedDigit())
                if !r.items.isEmpty {
                    Button(model.state(of: id) == .all ? tr("Deselect all") : tr("Select all")) { model.toggle(id) }
                        .buttonStyle(.link)
                }
            }
        }
        .padding(18)
    }

    @ViewBuilder private func empty(_ r: CategoryResult) -> some View {
        if r.needsAccess {
            ContentUnavailableView {
                Label(tr("Needs Full Disk Access"), systemImage: "lock")
            } description: {
                Text(tr("macOS keeps this folder private. Allow Besom in System Settings → Privacy & Security → Full Disk Access, then scan again."))
            } actions: {
                Button(tr("Open settings")) { openFullDiskAccess() }
            }
        } else if model.hasScanned {
            ContentUnavailableView(tr("Nothing to clean here"), systemImage: "checkmark.circle")
        } else {
            ProgressView(tr("Scanning…")).frame(maxHeight: .infinity)
        }
    }
}

private struct ItemRow: View {
    @ObservedObject var model: CleanerModel
    let item: CleanItem

    var body: some View {
        HStack(spacing: 10) {
            Button { model.toggle(item) } label: {
                SelectionBox(state: model.selected.contains(item.id) ? .all : .none)
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
            .help(tr("Show in Finder"))
            Text(bytes(item.size)).font(.callout.monospacedDigit()).frame(minWidth: 70, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Barre du bas

private struct FooterBar: View {
    @ObservedObject var model: CleanerModel

    var body: some View {
        HStack(spacing: 14) {
            status
            Spacer()
            Button { model.confirming = true } label: {
                Text(tr("Clean %@", bytes(model.selectedSize))).frame(minWidth: 130)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.selectedSize == 0 || model.isBusy)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
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
