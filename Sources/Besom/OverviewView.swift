import SwiftUI
import Charts

/// Page « Stockage » : où part la place sur le disque, et ce que Besom peut en récupérer.
struct OverviewView: View {
    @ObservedObject var storage: StorageModel
    @ObservedObject var model: CleanerModel
    @State private var hovered: StorageGroup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                tiles
                diskCard
                reclaimableCard
                foldersCard
                Text(tr("Folders protected by macOS may be undercounted without Full Disk Access."))
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Storage")).font(.largeTitle.weight(.bold))
                Text(tr("%@ used of %@ · %@ free", bytes(storage.used), bytes(storage.total), bytes(storage.free)))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if storage.phase == .measuring {
                HStack(spacing: 8) {
                    ProgressView(value: storage.progress).frame(width: 90)
                    Text(tr("Measuring…")).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Chiffres clés

    private var tiles: some View {
        HStack(spacing: 14) {
            StatTile(title: tr("Used"), value: bytes(storage.used), symbol: "internaldrive.fill", tint: Color(hue: 0.60, saturation: 0.65, brightness: 0.95))
            StatTile(title: tr("Free"), value: bytes(storage.free), symbol: "checkmark.circle.fill", tint: Color(hue: 0.38, saturation: 0.6, brightness: 0.85))
            StatTile(title: tr("Can be cleaned"), value: bytes(model.totalSize), symbol: "checkmark.seal.fill", tint: Color(hue: 0.47, saturation: 0.6, brightness: 0.85))
        }
    }

    // MARK: Disque

    private var diskCard: some View {
        HStack(spacing: 26) {
            donut.frame(width: 240, height: 240)
            legend
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var donut: some View {
        Chart(storage.slices) { s in
            SectorMark(angle: .value("Size", s.bytes), innerRadius: .ratio(0.66), angularInset: 1.4)
                .cornerRadius(5)
                .foregroundStyle(s.group.color)
                .opacity(hovered == nil || hovered == s.group ? 1 : 0.35)
        }
        .chartLegend(.hidden)
        .animation(.easeOut(duration: 0.25), value: hovered)
        .animation(.easeOut(duration: 0.4), value: storage.slices.map(\.bytes))
        .overlay {
            VStack(spacing: 2) {
                if let h = hovered, let s = storage.slices.first(where: { $0.group == h }) {
                    Image(systemName: h.symbol).font(.title3).foregroundStyle(h.color)
                    Text(bytes(s.bytes)).font(.title2.weight(.bold).monospacedDigit())
                    Text(h.title).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(bytes(storage.used)).font(.title.weight(.bold).monospacedDigit())
                    Text(tr("used")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .animation(.none, value: hovered)
        }
    }

    private var legend: some View {
        VStack(spacing: 2) {
            ForEach(storage.slices) { s in
                HStack(spacing: 9) {
                    Circle().fill(s.group.color).frame(width: 10, height: 10)
                    Text(s.group.title).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(bytes(s.bytes)).monospacedDigit().foregroundStyle(.secondary).lineLimit(1).fixedSize()
                    Text(percent(s.bytes)).monospacedDigit().foregroundStyle(.tertiary).lineLimit(1).fixedSize()
                        .frame(width: 48, alignment: .trailing)
                }
                .font(.callout)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.primary.opacity(hovered == s.group ? 0.08 : 0)))
                .contentShape(Rectangle())
                .onHover { hovered = $0 ? s.group : (hovered == s.group ? nil : hovered) }
            }
            if storage.slices.isEmpty { ProgressView().frame(maxWidth: .infinity) }
        }
        .frame(maxWidth: .infinity)
    }

    private func percent(_ n: Int64) -> String {
        guard storage.total > 0 else { return "" }
        let p = Double(n) / Double(storage.total) * 100
        return p < 1 ? "<1 %" : String(format: "%.0f %%", p)
    }

    // MARK: À récupérer

    private var reclaimableCard: some View {
        let parts = model.results.filter { $0.totalSize > 0 }
        let total = max(model.totalSize, 1)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(tr("Can be cleaned"), systemImage: "checkmark.seal.fill").font(.headline)
                Spacer()
                Text(bytes(model.totalSize)).font(.title3.weight(.bold).monospacedDigit())
            }
            if parts.isEmpty {
                Text(model.hasScanned ? tr("Nothing to clean here") : tr("Scanning…")).foregroundStyle(.secondary)
            } else {
                GeometryReader { g in
                    HStack(spacing: 3) {
                        ForEach(parts) { r in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(colors: [r.id.tint, r.id.tint.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                                .frame(width: max(4, (g.size.width - 3 * CGFloat(parts.count - 1)) * CGFloat(r.totalSize) / CGFloat(total)))
                                .help("\(r.id.title) · \(bytes(r.totalSize))")
                        }
                    }
                }
                .frame(height: 22)
                FlowLegend(items: parts.map { ($0.id.title, $0.id.tint, bytes($0.totalSize)) })
            }
            if storage.total > 0, model.totalSize > 0 {
                Text(tr("That is %@ of your disk.", String(format: "%.1f %%", Double(model.totalSize) / Double(storage.total) * 100)))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: Plus gros dossiers

    private var foldersCard: some View {
        let top = Array(storage.folders.prefix(10))
        return VStack(alignment: .leading, spacing: 12) {
            Label(tr("Largest folders"), systemImage: "chart.bar.fill").font(.headline)
            if top.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(top) { f in
                    BarMark(x: .value("Size", f.bytes), y: .value("Folder", f.unit.label))
                        .cornerRadius(6)
                        .foregroundStyle(LinearGradient(colors: [f.unit.group.color, f.unit.group.color.opacity(0.65)],
                                                        startPoint: .leading, endPoint: .trailing))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text(bytes(f.bytes)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: top.map(\.unit.label))
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks { _ in AxisValueLabel().font(.callout) } }
                .chartXScale(range: .plotDimension(endPadding: 70))
                .frame(height: CGFloat(top.count) * 32 + 8)
                .animation(.easeOut(duration: 0.4), value: top.map(\.bytes))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// Légende qui passe à la ligne.
struct FlowLegend: View {
    let items: [(String, Color, String)]

    var body: some View {
        FlowLayout(spacing: 14, lineSpacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    Circle().fill(items[i].1).frame(width: 9, height: 9)
                    Text(items[i].0).font(.callout)
                    Text(items[i].2).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 600, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (i, origin) in result.origins.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        var origins: [CGPoint] = []
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0, x + s.width > width { x = 0; y += rowHeight + lineSpacing; rowHeight = 0 }
            origins.append(CGPoint(x: x, y: y))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(0.18)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title3.weight(.bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 22, tint: tint)
    }
}
