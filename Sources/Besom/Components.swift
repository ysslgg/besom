import SwiftUI

/// Pastille d'icône teintée (barre latérale, en-têtes).
func iconBadge(_ symbol: String, _ tint: Color, dimmed: Bool = false, size: CGFloat = 30) -> some View {
    Image(systemName: symbol)
        .font(.system(size: size * 0.43, weight: .semibold))
        .foregroundStyle(dimmed ? Color.secondary : tint)
        .frame(width: size, height: size)
        .background(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill((dimmed ? Color.secondary : tint).opacity(0.16)))
}

/// En-tête de page : icône, titre, sous-titre et actions à droite.
struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            iconBadge(symbol, tint, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title2.weight(.semibold))
                Text(subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            trailing().fixedSize()
        }
        .padding(16)
        .glassCard()
    }
}

/// Ligne de liste sur fond translucide.
struct GlassRow<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) { content() }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.primary.opacity(hovering ? 0.09 : 0.05)))
            .onHover { hovering = $0 }
    }
}

struct SearchField: View {
    @Binding var text: String
    var prompt: String
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(prompt, text: $text).textFieldStyle(.plain).onSubmit(onSubmit)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .glassCard(radius: 14)
    }
}

struct Pill: View {
    let text: String
    var tint: Color = .secondary
    var body: some View {
        Text(text).font(.caption2.weight(.semibold)).foregroundStyle(tint)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.16)))
    }
}

/// Terminal : montre en direct les commandes lancées et leur sortie.
struct TerminalPanel: View {
    let lines: [String]
    var busy: String?
    var onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(.red.opacity(0.8)).frame(width: 9, height: 9)
                Circle().fill(.yellow.opacity(0.8)).frame(width: 9, height: 9)
                Circle().fill(.green.opacity(0.8)).frame(width: 9, height: 9)
                Text("Terminal — brew").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.6)).padding(.leading, 6)
                Spacer()
                if busy != nil { ProgressView().controlSize(.mini).tint(.white) }
                Button(tr("Clear output"), action: onClear)
                    .buttonStyle(.plain).font(.caption).foregroundStyle(.white.opacity(lines.isEmpty ? 0.25 : 0.7))
                    .disabled(lines.isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.white.opacity(0.06))

            do {
                ScrollView {
                    VStack(alignment: .leading, spacing: 1) {
                        if lines.isEmpty {
                            Text(tr("Commands and their output show up here as they run."))
                                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
                        }
                        ForEach(lines.indices, id: \.self) { i in
                            Text(lines[i])
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(lines[i].hasPrefix("$") ? Color(hue: 0.38, saturation: 0.5, brightness: 1) : .white.opacity(0.82))
                                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).id(i)
                        }
                        if busy != nil { Text("▍").font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.6)) }
                    }
                    .padding(12)
                }
                // Reste calé en bas quand de nouvelles lignes arrivent (sans faire défiler la page autour).
                .defaultScrollAnchor(.bottom)
            }
        }
        .frame(height: 210)
        .background(Color.black.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

/// Page standard : défilement avec marges (laisse la place à la barre flottante).
struct PageScroll<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(spacing: 14) { content() }
                .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }
}
