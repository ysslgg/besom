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

/// Applique le verre (Liquid Glass sur macOS 26+, matériau flou avant) selon les réglages de transparence.
private struct GlassModifier: ViewModifier {
    let shape: AnyShape
    let tint: Color?
    @ObservedObject private var prefs = Prefs.shared
    @Environment(\.colorScheme) private var scheme

    @available(macOS 26.0, *)
    private func makeGlass() -> Glass {
        var glass: Glass = prefs.glassStyle == .clear ? .clear : .regular
        if let tint { glass = glass.tint(tint.opacity(0.4 * prefs.glassTint)) }
        return glass
    }

    func body(content: Content) -> some View {
        // Le « dépoli » ajoute une couche translucide sous le verre : plus il monte, moins le fond se voit.
        let frost = (scheme == .dark ? Color.black : Color.white).opacity(prefs.glassFrost * 0.75)
        if #available(macOS 26.0, *) {
            content.background(frost, in: shape).glassEffect(makeGlass(), in: shape)
        } else {
            content
                .background(prefs.glassStyle == .clear ? .ultraThinMaterial : .thinMaterial, in: shape)
                .background(frost, in: shape)
                .overlay(shape.stroke(.white.opacity(0.18), lineWidth: 0.8))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        }
    }
}

extension View {
    /// Carte en verre.
    func glassCard(radius: CGFloat = 22, tint: Color? = nil) -> some View {
        modifier(GlassModifier(shape: AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous)), tint: tint))
    }

    func glassCapsule() -> some View {
        modifier(GlassModifier(shape: AnyShape(Capsule()), tint: nil))
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
    @ObservedObject private var prefs = Prefs.shared

    var body: some View {
        let dark = scheme == .dark
        let h = prefs.theme.hues
        let sat = prefs.theme.saturation
        ZStack {
            (dark ? Color(red: 0.05, green: 0.07, blue: 0.09) : Color(red: 0.94, green: 0.96, blue: 0.97))
            GeometryReader { g in
                Circle().fill(Color(hue: h[0], saturation: sat * 1.05, brightness: dark ? 0.75 : 0.95))
                    .frame(width: g.size.width * 0.7).offset(x: -g.size.width * 0.15, y: -g.size.height * 0.25)
                Circle().fill(Color(hue: h[1], saturation: sat * 0.95, brightness: dark ? 0.70 : 1.0))
                    .frame(width: g.size.width * 0.55).offset(x: g.size.width * 0.55, y: g.size.height * 0.05)
                Circle().fill(Color(hue: h[2], saturation: sat * 0.80, brightness: dark ? 0.60 : 0.95))
                    .frame(width: g.size.width * 0.6).offset(x: g.size.width * 0.1, y: g.size.height * 0.62)
            }
            .blur(radius: 90)
            .opacity(prefs.auroraIntensity)
        }
        .ignoresSafeArea()
    }
}
