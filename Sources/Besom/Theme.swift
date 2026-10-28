import SwiftUI

extension CategoryID {
    var tint: Color {
        switch self {
        case .caches: Color(hue: 0.47, saturation: 0.60, brightness: 0.85)
        case .logs: Color(hue: 0.13, saturation: 0.65, brightness: 1.0)
        case .temp: Color(hue: 0.07, saturation: 0.70, brightness: 1.0)
        case .devCaches: Color(hue: 0.68, saturation: 0.55, brightness: 0.95)
        case .orphans: Color(hue: 0.78, saturation: 0.50, brightness: 0.95)
        case .installers: Color(hue: 0.93, saturation: 0.50, brightness: 1.0)
        case .backups: Color(hue: 0.58, saturation: 0.60, brightness: 0.95)
        case .trash: Color(white: 0.60)
        }
    }
}

extension View {
    /// Carte en verre : Liquid Glass sur macOS 26 et plus, matériau flou en dessous.
    @ViewBuilder func glassCard(radius: CGFloat = 22, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint.opacity(0.18)), in: .rect(cornerRadius: radius))
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: radius))
            }
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
    }

    @ViewBuilder func glassCapsule() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.8))
        }
    }

    @ViewBuilder func prominentGlassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder func glassButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

/// Fond coloré et doux, qui donne au verre quelque chose à réfracter.
struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        ZStack {
            (dark ? Color(red: 0.05, green: 0.08, blue: 0.10) : Color(red: 0.92, green: 0.97, blue: 0.97))
            GeometryReader { g in
                Circle().fill(Color(hue: 0.47, saturation: 0.75, brightness: dark ? 0.75 : 0.95))
                    .frame(width: g.size.width * 0.7).offset(x: -g.size.width * 0.15, y: -g.size.height * 0.25)
                Circle().fill(Color(hue: 0.60, saturation: 0.65, brightness: dark ? 0.70 : 1.0))
                    .frame(width: g.size.width * 0.55).offset(x: g.size.width * 0.55, y: g.size.height * 0.05)
                Circle().fill(Color(hue: 0.38, saturation: 0.55, brightness: dark ? 0.60 : 0.95))
                    .frame(width: g.size.width * 0.6).offset(x: g.size.width * 0.1, y: g.size.height * 0.62)
            }
            .blur(radius: 90)
            .opacity(dark ? 0.55 : 0.60)
        }
        .ignoresSafeArea()
    }
}
