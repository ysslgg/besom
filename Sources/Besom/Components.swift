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

/// Console de sortie des commandes (Homebrew…).
struct LogConsole: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i]).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).id(i)
                    }
                }
                .padding(12)
            }
            .onChange(of: lines.count) { _, n in if n > 0 { proxy.scrollTo(n - 1, anchor: .bottom) } }
        }
        .frame(height: 150)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.black.opacity(0.18)))
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
