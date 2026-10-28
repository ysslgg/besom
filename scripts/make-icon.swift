// Génère l'icône de Besom. Usage : swift scripts/make-icon.swift <sortie.png> [a|b|c|d|e|f|g|h|i]
import AppKit
import CoreGraphics

let S: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let style = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "a"
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }
func grad(_ cols: [CGColor], _ locs: [CGFloat]) -> CGGradient { CGGradient(colorsSpace: cs, colors: cols as CFArray, locations: locs)! }
func radial(_ c: CGPoint, _ r: CGFloat, _ inner: CGColor, _ outer: CGColor) {
    ctx.drawRadialGradient(grad([inner, outer], [0, 1]), startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
}

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 190, cornerHeight: 190, transform: nil)

func sparkle(_ c: CGPoint, _ r: CGFloat, _ fill: CGColor, glow: CGColor? = nil) {
    let k = r * 0.14
    let p = CGMutablePath()
    p.move(to: CGPoint(x: c.x, y: c.y + r))
    p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y + k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x + k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x - k, y: c.y + k))
    p.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: r * 0.5, color: glow ?? col(1, 1, 1, 0.8))
    ctx.addPath(p); ctx.setFillColor(fill); ctx.fillPath()
    ctx.restoreGState()
}

// Ombre
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 40, color: col(0, 0.1, 0.15, 0.5))
ctx.addPath(squircle); ctx.setFillColor(col(0.05, 0.3, 0.35)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle); ctx.clip()

switch style {
case "b":
    // Anneau de stockage, une part dégagée par une étincelle
    ctx.drawLinearGradient(grad([col(0.03, 0.07, 0.14), col(0.06, 0.18, 0.30), col(0.05, 0.30, 0.38)], [0, 0.6, 1]),
                           start: CGPoint(x: 200, y: 924), end: CGPoint(x: 800, y: 100), options: [])
    let c = CGPoint(x: 512, y: 512)
    radial(c, 420, col(0.2, 0.8, 0.8, 0.30), col(0.2, 0.8, 0.8, 0))
    let segs: [(CGFloat, CGFloat, CGColor, CGColor)] = [
        (90, 190, col(0.30, 0.62, 1.0), col(0.55, 0.80, 1.0)),
        (195, 265, col(1.0, 0.62, 0.30), col(1.0, 0.82, 0.45)),
        (270, 305, col(0.78, 0.50, 1.0), col(0.90, 0.70, 1.0)),
        (310, 395, col(0.25, 0.85, 0.75), col(0.55, 1.0, 0.85)),
    ]
    ctx.setLineCap(.round)
    ctx.setLineWidth(96)
    ctx.setStrokeColor(col(1, 1, 1, 0.10))
    ctx.addArc(center: c, radius: 270, startAngle: 0, endAngle: .pi * 2, clockwise: false); ctx.strokePath()
    for (a0, a1, c0, c1) in segs {
        ctx.saveGState()
        ctx.setLineWidth(96); ctx.setLineCap(.round)
        ctx.addArc(center: c, radius: 270, startAngle: a0 * .pi / 180, endAngle: a1 * .pi / 180, clockwise: false)
        ctx.replacePathWithStrokedPath(); ctx.clip()
        ctx.drawLinearGradient(grad([c0, c1], [0, 1]), start: CGPoint(x: 242, y: 780), end: CGPoint(x: 782, y: 240), options: [])
        ctx.restoreGState()
    }
    sparkle(c, 170, col(1, 1, 1), glow: col(0.6, 1, 0.95, 0.9))
    sparkle(CGPoint(x: 740, y: 740), 52, col(1, 1, 1, 0.9))

case "e":
    // Monogramme « B » en verre
    ctx.drawLinearGradient(grad([col(0.05, 0.10, 0.30), col(0.03, 0.30, 0.46), col(0.02, 0.58, 0.60)], [0, 0.55, 1]),
                           start: CGPoint(x: 120, y: 960), end: CGPoint(x: 880, y: 90), options: [])
    radial(CGPoint(x: 800, y: 840), 560, col(0.40, 0.95, 0.80, 0.55), col(0.40, 0.95, 0.80, 0))
    radial(CGPoint(x: 160, y: 200), 520, col(0.55, 0.35, 1.0, 0.45), col(0.55, 0.35, 1.0, 0))
    let base = NSFont.systemFont(ofSize: 800, weight: .black)
    let desc = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    let font = CTFontCreateWithFontDescriptor(desc, 800, nil)
    var ch: UniChar = 66
    var glyph = CGGlyph()
    CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1)
    let raw = CTFontCreatePathForGlyph(font, glyph, nil)!
    let bb = raw.boundingBox
    var tf = CGAffineTransform(translationX: 512 - bb.midX, y: 500 - bb.midY)
    let glyphPath = raw.copy(using: &tf)!
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 10, height: -22), blur: 40, color: col(0, 0.05, 0.15, 0.6))
    ctx.addPath(glyphPath); ctx.setFillColor(col(1, 1, 1)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(glyphPath); ctx.clip()
    ctx.drawLinearGradient(grad([col(1, 1, 1), col(0.84, 0.96, 0.98), col(0.62, 0.86, 0.94)], [0, 0.5, 1]),
                           start: CGPoint(x: 300, y: 860), end: CGPoint(x: 700, y: 150), options: [])
    ctx.drawLinearGradient(grad([col(1, 1, 1, 0.8), col(1, 1, 1, 0)], [0, 1]),
                           start: CGPoint(x: 300, y: 800), end: CGPoint(x: 300, y: 560), options: [])
    ctx.restoreGState()
    ctx.addPath(glyphPath); ctx.setStrokeColor(col(1, 1, 1, 0.7)); ctx.setLineWidth(3); ctx.strokePath()
    sparkle(CGPoint(x: 760, y: 790), 130, col(1, 1, 1), glow: col(0.6, 1, 0.95, 1))
    sparkle(CGPoint(x: 800, y: 600), 42, col(1, 1, 1, 0.9))
    sparkle(CGPoint(x: 250, y: 250), 50, col(1, 1, 1, 0.85))

case "f":
    // Disques de stockage empilés
    ctx.drawLinearGradient(grad([col(0.05, 0.08, 0.26), col(0.04, 0.22, 0.44), col(0.02, 0.52, 0.58)], [0, 0.55, 1]),
                           start: CGPoint(x: 120, y: 960), end: CGPoint(x: 880, y: 90), options: [])
    radial(CGPoint(x: 780, y: 860), 560, col(0.40, 0.95, 0.80, 0.5), col(0.40, 0.95, 0.80, 0))
    radial(CGPoint(x: 200, y: 200), 500, col(0.55, 0.35, 1.0, 0.4), col(0.55, 0.35, 1.0, 0))
    let layers: [(CGFloat, CGColor, CGColor, CGColor)] = [
        (300, col(0.07, 0.30, 0.55), col(0.20, 0.52, 0.85), col(0.36, 0.66, 0.98)),
        (445, col(0.05, 0.42, 0.55), col(0.15, 0.68, 0.78), col(0.35, 0.86, 0.90)),
        (590, col(0.55, 0.72, 0.80), col(0.85, 0.96, 0.98), col(1, 1, 1)),
    ]
    let rx: CGFloat = 300, ry: CGFloat = 125, th: CGFloat = 52
    for (cy, side, topA, topB) in layers {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: col(0, 0.05, 0.15, 0.45))
        let slab = CGMutablePath()
        slab.addEllipse(in: CGRect(x: 512 - rx, y: cy - th - ry, width: 2 * rx, height: 2 * ry))
        slab.addRect(CGRect(x: 512 - rx, y: cy - th, width: 2 * rx, height: th))
        ctx.addPath(slab); ctx.setFillColor(side); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState(); ctx.addPath(slab); ctx.clip()
        ctx.drawLinearGradient(grad([col(1, 1, 1, 0.25), col(0, 0, 0, 0.25)], [0, 1]),
                               start: CGPoint(x: 512 - rx, y: 0), end: CGPoint(x: 512 + rx, y: 0), options: [])
        ctx.restoreGState()
        let top = CGPath(ellipseIn: CGRect(x: 512 - rx, y: cy - ry, width: 2 * rx, height: 2 * ry), transform: nil)
        ctx.saveGState(); ctx.addPath(top); ctx.clip()
        ctx.drawLinearGradient(grad([topB, topA], [0, 1]), start: CGPoint(x: 300, y: cy + ry), end: CGPoint(x: 700, y: cy - ry), options: [])
        ctx.restoreGState()
        ctx.addPath(top); ctx.setStrokeColor(col(1, 1, 1, 0.65)); ctx.setLineWidth(3); ctx.strokePath()
    }
    sparkle(CGPoint(x: 512, y: 690), 120, col(0.1, 0.62, 0.70), glow: col(0.3, 0.9, 0.9, 0.9))
    sparkle(CGPoint(x: 800, y: 790), 70, col(1, 1, 1), glow: col(0.6, 1, 0.95, 0.9))
    sparkle(CGPoint(x: 230, y: 760), 46, col(1, 1, 1, 0.9))

case "g":
    // Bulle de verre avec une étincelle
    ctx.drawLinearGradient(grad([col(0.05, 0.08, 0.26), col(0.04, 0.22, 0.44), col(0.02, 0.52, 0.58)], [0, 0.55, 1]),
                           start: CGPoint(x: 120, y: 960), end: CGPoint(x: 880, y: 90), options: [])
    radial(CGPoint(x: 800, y: 860), 560, col(0.40, 0.95, 0.80, 0.45), col(0.40, 0.95, 0.80, 0))
    radial(CGPoint(x: 180, y: 220), 520, col(0.55, 0.35, 1.0, 0.45), col(0.55, 0.35, 1.0, 0))
    let c = CGPoint(x: 512, y: 520), R: CGFloat = 310
    // Ombre au sol
    ctx.saveGState()
    ctx.setFillColor(col(0, 0.05, 0.12, 0.45))
    ctx.setShadow(offset: .zero, blur: 40, color: col(0, 0.05, 0.12, 0.5))
    ctx.fillEllipse(in: CGRect(x: 512 - 230, y: 175, width: 460, height: 70))
    ctx.restoreGState()
    let orb = CGPath(ellipseIn: CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R), transform: nil)
    ctx.saveGState(); ctx.addPath(orb); ctx.clip()
    ctx.drawLinearGradient(grad([col(0.85, 1, 0.98, 0.55), col(0.25, 0.80, 0.85, 0.40), col(0.10, 0.45, 0.75, 0.55)], [0, 0.5, 1]),
                           start: CGPoint(x: 300, y: 820), end: CGPoint(x: 720, y: 220), options: [])
    radial(CGPoint(x: 640, y: 330), 300, col(0.55, 1, 0.85, 0.65), col(0.55, 1, 0.85, 0))
    radial(CGPoint(x: 380, y: 700), 260, col(1, 1, 1, 0.55), col(1, 1, 1, 0))
    ctx.restoreGState()
    ctx.addPath(orb); ctx.setStrokeColor(col(1, 1, 1, 0.65)); ctx.setLineWidth(4); ctx.strokePath()
    // Reflet spéculaire
    ctx.saveGState()
    ctx.translateBy(x: 400, y: 735); ctx.rotate(by: 30 * .pi / 180)
    ctx.setFillColor(col(1, 1, 1, 0.75))
    ctx.fillEllipse(in: CGRect(x: -105, y: -34, width: 210, height: 68))
    ctx.restoreGState()
    sparkle(CGPoint(x: 560, y: 480), 190, col(1, 1, 1), glow: col(0.6, 1, 0.95, 1))
    sparkle(CGPoint(x: 780, y: 760), 52, col(1, 1, 1, 0.9))
    sparkle(CGPoint(x: 250, y: 330), 40, col(1, 1, 1, 0.85))

case "d":
    // Balai de verre, monochrome blanc sur fond riche
    ctx.drawLinearGradient(grad([col(0.05, 0.10, 0.30), col(0.03, 0.30, 0.46), col(0.02, 0.58, 0.60)], [0, 0.55, 1]),
                           start: CGPoint(x: 120, y: 960), end: CGPoint(x: 880, y: 90), options: [])
    radial(CGPoint(x: 800, y: 840), 560, col(0.40, 0.95, 0.80, 0.55), col(0.40, 0.95, 0.80, 0))
    radial(CGPoint(x: 160, y: 200), 520, col(0.55, 0.35, 1.0, 0.45), col(0.55, 0.35, 1.0, 0))
    radial(CGPoint(x: 520, y: 520), 360, col(1, 1, 1, 0.20), col(1, 1, 1, 0))
    ctx.saveGState()
    ctx.translateBy(x: 540, y: 535)
    ctx.rotate(by: -38 * .pi / 180)
    ctx.scaleBy(x: 1.08, y: 1.08)
    let head = CGMutablePath()
    head.move(to: CGPoint(x: -56, y: -70))
    head.addCurve(to: CGPoint(x: -180, y: -335), control1: CGPoint(x: -70, y: -170), control2: CGPoint(x: -176, y: -250))
    head.addQuadCurve(to: CGPoint(x: 180, y: -335), control: CGPoint(x: 0, y: -400))
    head.addCurve(to: CGPoint(x: 56, y: -70), control1: CGPoint(x: 176, y: -250), control2: CGPoint(x: 70, y: -170))
    head.closeSubpath()
    let handle = CGPath(roundedRect: CGRect(x: -21, y: -60, width: 42, height: 400), cornerWidth: 21, cornerHeight: 21, transform: nil)
    let band = CGPath(roundedRect: CGRect(x: -98, y: -138, width: 196, height: 84), cornerWidth: 28, cornerHeight: 28, transform: nil)
    // Halo et ombre
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 12, height: -24), blur: 44, color: col(0, 0.05, 0.15, 0.6))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(col(1, 1, 1))
    for p in [handle, head, band] { ctx.addPath(p); ctx.fillPath() }
    ctx.endTransparencyLayer()
    ctx.restoreGState()
    // Manche : verre blanc
    ctx.saveGState(); ctx.addPath(handle); ctx.clip()
    ctx.drawLinearGradient(grad([col(0.80, 0.93, 0.98), col(1, 1, 1), col(0.72, 0.88, 0.95)], [0, 0.4, 1]),
                           start: CGPoint(x: -21, y: 0), end: CGPoint(x: 21, y: 0), options: [])
    ctx.restoreGState()
    // Poils : verre dépoli, brins fins
    ctx.saveGState(); ctx.addPath(head); ctx.clip()
    ctx.drawLinearGradient(grad([col(0.70, 0.90, 0.97), col(0.92, 0.98, 1), col(1, 1, 1)], [0, 0.5, 1]),
                           start: CGPoint(x: 0, y: -70), end: CGPoint(x: 0, y: -400), options: [])
    ctx.setLineCap(.round)
    for i in -8...8 {
        let t = CGFloat(i)
        ctx.setStrokeColor(col(0.10, 0.45, 0.60, i % 2 == 0 ? 0.28 : 0.12)); ctx.setLineWidth(i % 2 == 0 ? 5 : 3)
        ctx.move(to: CGPoint(x: t * 7, y: -70)); ctx.addLine(to: CGPoint(x: t * 24, y: -410)); ctx.strokePath()
    }
    ctx.drawLinearGradient(grad([col(1, 1, 1, 0.9), col(1, 1, 1, 0)], [0, 1]), start: CGPoint(x: -185, y: -250), end: CGPoint(x: -10, y: -250), options: [])
    ctx.restoreGState()
    // Bague : teal profond pour le contraste
    ctx.saveGState(); ctx.addPath(band); ctx.clip()
    ctx.drawLinearGradient(grad([col(0.10, 0.62, 0.70), col(0.03, 0.34, 0.50), col(0.02, 0.24, 0.40)], [0, 0.5, 1]),
                           start: CGPoint(x: 0, y: -54), end: CGPoint(x: 0, y: -138), options: [])
    ctx.drawLinearGradient(grad([col(1, 1, 1, 0.45), col(1, 1, 1, 0)], [0, 1]),
                           start: CGPoint(x: 0, y: -54), end: CGPoint(x: 0, y: -90), options: [])
    ctx.restoreGState()
    ctx.addPath(band); ctx.setStrokeColor(col(1, 1, 1, 0.55)); ctx.setLineWidth(3); ctx.strokePath()
    ctx.restoreGState()
    sparkle(CGPoint(x: 270, y: 785), 105, col(1, 1, 1), glow: col(0.6, 1, 0.95, 0.95))
    sparkle(CGPoint(x: 800, y: 285), 125, col(1, 1, 1), glow: col(0.6, 0.9, 1, 0.95))
    sparkle(CGPoint(x: 855, y: 535), 44, col(1, 1, 1, 0.9))
    sparkle(CGPoint(x: 395, y: 880), 30, col(1, 1, 1, 0.8))

case "c":
    // Verre clair, un coup de balai
    ctx.drawLinearGradient(grad([col(0.99, 1.0, 1.0), col(0.84, 0.97, 0.93), col(0.62, 0.92, 0.86)], [0, 0.55, 1]),
                           start: CGPoint(x: 200, y: 924), end: CGPoint(x: 800, y: 100), options: [])
    radial(CGPoint(x: 780, y: 820), 420, col(0.5, 0.85, 1.0, 0.45), col(0.5, 0.85, 1.0, 0))
    // Traînée de balai
    let sweep = CGMutablePath()
    sweep.move(to: CGPoint(x: 220, y: 330))
    sweep.addCurve(to: CGPoint(x: 800, y: 700), control1: CGPoint(x: 340, y: 230), control2: CGPoint(x: 700, y: 330))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 26, color: col(0, 0.35, 0.35, 0.35))
    ctx.setLineWidth(170); ctx.setLineCap(.round)
    ctx.addPath(sweep); ctx.replacePathWithStrokedPath()
    ctx.setFillColor(col(0.1, 0.7, 0.68)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.setLineWidth(170); ctx.setLineCap(.round)
    ctx.addPath(sweep); ctx.replacePathWithStrokedPath(); ctx.clip()
    ctx.drawLinearGradient(grad([col(0.05, 0.55, 0.60), col(0.15, 0.78, 0.72), col(0.55, 0.95, 0.80)], [0, 0.5, 1]),
                           start: CGPoint(x: 220, y: 300), end: CGPoint(x: 800, y: 720), options: [])
    // Brins
    ctx.setLineCap(.round)
    for i in -5...5 {
        let off = CGFloat(i) * 15
        let line = CGMutablePath()
        line.move(to: CGPoint(x: 220 + off * 0.3, y: 330 + off))
        line.addCurve(to: CGPoint(x: 800 + off * 0.3, y: 700 + off), control1: CGPoint(x: 340, y: 230 + off), control2: CGPoint(x: 700, y: 330 + off))
        ctx.addPath(line); ctx.setStrokeColor(col(1, 1, 1, i % 2 == 0 ? 0.28 : 0.12)); ctx.setLineWidth(4); ctx.strokePath()
    }
    ctx.restoreGState()
    sparkle(CGPoint(x: 330, y: 700), 120, col(0.12, 0.72, 0.68), glow: col(0.3, 0.9, 0.85, 0.7))
    sparkle(CGPoint(x: 620, y: 880 - 120), 60, col(0.25, 0.55, 0.95), glow: col(0.4, 0.7, 1, 0.7))
    sparkle(CGPoint(x: 790, y: 330), 52, col(0.12, 0.72, 0.68), glow: col(0.3, 0.9, 0.85, 0.7))

case "h":
    // Disques de stockage empilés, coche de validation
    ctx.drawLinearGradient(grad([col(0.05, 0.08, 0.26), col(0.04, 0.22, 0.44), col(0.02, 0.52, 0.58)], [0, 0.55, 1]),
                           start: CGPoint(x: 120, y: 960), end: CGPoint(x: 880, y: 90), options: [])
    radial(CGPoint(x: 780, y: 860), 560, col(0.40, 0.95, 0.80, 0.5), col(0.40, 0.95, 0.80, 0))
    radial(CGPoint(x: 200, y: 200), 500, col(0.55, 0.35, 1.0, 0.4), col(0.55, 0.35, 1.0, 0))
    let layers: [(CGFloat, CGColor, CGColor, CGColor)] = [
        (300, col(0.07, 0.30, 0.55), col(0.20, 0.52, 0.85), col(0.36, 0.66, 0.98)),
        (445, col(0.05, 0.42, 0.55), col(0.15, 0.68, 0.78), col(0.35, 0.86, 0.90)),
        (590, col(0.55, 0.72, 0.80), col(0.85, 0.96, 0.98), col(1, 1, 1)),
    ]
    let rx: CGFloat = 300, ry: CGFloat = 125, th: CGFloat = 52
    for (cy, side, topA, topB) in layers {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 30, color: col(0, 0.05, 0.15, 0.45))
        let slab = CGMutablePath()
        slab.addEllipse(in: CGRect(x: 512 - rx, y: cy - th - ry, width: 2 * rx, height: 2 * ry))
        slab.addRect(CGRect(x: 512 - rx, y: cy - th, width: 2 * rx, height: th))
        ctx.addPath(slab); ctx.setFillColor(side); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState(); ctx.addPath(slab); ctx.clip()
        ctx.drawLinearGradient(grad([col(1, 1, 1, 0.25), col(0, 0, 0, 0.25)], [0, 1]),
                               start: CGPoint(x: 512 - rx, y: 0), end: CGPoint(x: 512 + rx, y: 0), options: [])
        ctx.restoreGState()
        let top = CGPath(ellipseIn: CGRect(x: 512 - rx, y: cy - ry, width: 2 * rx, height: 2 * ry), transform: nil)
        ctx.saveGState(); ctx.addPath(top); ctx.clip()
        ctx.drawLinearGradient(grad([topB, topA], [0, 1]), start: CGPoint(x: 300, y: cy + ry), end: CGPoint(x: 700, y: cy - ry), options: [])
        ctx.restoreGState()
        ctx.addPath(top); ctx.setStrokeColor(col(1, 1, 1, 0.65)); ctx.setLineWidth(3); ctx.strokePath()
    }
    // Coche sur le disque du dessus
    let check = CGMutablePath()
    check.move(to: CGPoint(x: 405, y: 600)); check.addLine(to: CGPoint(x: 480, y: 548)); check.addLine(to: CGPoint(x: 632, y: 655))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 14, color: col(0, 0.2, 0.3, 0.35))
    ctx.setLineWidth(58); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.addPath(check); ctx.replacePathWithStrokedPath(); ctx.clip()
    ctx.drawLinearGradient(grad([col(0.05, 0.60, 0.66), col(0.10, 0.45, 0.80)], [0, 1]), start: CGPoint(x: 400, y: 540), end: CGPoint(x: 640, y: 670), options: [])
    ctx.restoreGState()

case "i":
    // Monogramme « B » en verre, sans étoile
    ctx.drawLinearGradient(grad([col(0.05, 0.10, 0.30), col(0.03, 0.30, 0.46), col(0.02, 0.58, 0.60)], [0, 0.55, 1]),
                           start: CGPoint(x: 120, y: 960), end: CGPoint(x: 880, y: 90), options: [])
    radial(CGPoint(x: 800, y: 840), 560, col(0.40, 0.95, 0.80, 0.55), col(0.40, 0.95, 0.80, 0))
    radial(CGPoint(x: 160, y: 200), 520, col(0.55, 0.35, 1.0, 0.45), col(0.55, 0.35, 1.0, 0))
    let base = NSFont.systemFont(ofSize: 800, weight: .black)
    let desc = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    let font = CTFontCreateWithFontDescriptor(desc, 800, nil)
    var ch: UniChar = 66
    var glyph = CGGlyph()
    CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1)
    let raw = CTFontCreatePathForGlyph(font, glyph, nil)!
    let bb = raw.boundingBox
    var tf = CGAffineTransform(translationX: 512 - bb.midX, y: 500 - bb.midY)
    let glyphPath = raw.copy(using: &tf)!
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 10, height: -22), blur: 40, color: col(0, 0.05, 0.15, 0.6))
    ctx.addPath(glyphPath); ctx.setFillColor(col(1, 1, 1)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(glyphPath); ctx.clip()
    ctx.drawLinearGradient(grad([col(1, 1, 1), col(0.84, 0.96, 0.98), col(0.62, 0.86, 0.94)], [0, 0.5, 1]),
                           start: CGPoint(x: 300, y: 860), end: CGPoint(x: 700, y: 150), options: [])
    ctx.drawLinearGradient(grad([col(1, 1, 1, 0.8), col(1, 1, 1, 0)], [0, 1]),
                           start: CGPoint(x: 300, y: 800), end: CGPoint(x: 300, y: 560), options: [])
    ctx.restoreGState()
    ctx.addPath(glyphPath); ctx.setStrokeColor(col(1, 1, 1, 0.7)); ctx.setLineWidth(3); ctx.strokePath()
default:
    // Balai en verre sur fond profond
    ctx.drawLinearGradient(grad([col(0.02, 0.12, 0.20), col(0.04, 0.30, 0.38), col(0.10, 0.55, 0.55)], [0, 0.55, 1]),
                           start: CGPoint(x: 150, y: 960), end: CGPoint(x: 850, y: 100), options: [])
    radial(CGPoint(x: 700, y: 700), 520, col(0.45, 0.95, 0.85, 0.35), col(0.45, 0.95, 0.85, 0))
    ctx.saveGState()
    ctx.translateBy(x: 545, y: 540)
    ctx.rotate(by: -38 * .pi / 180)
    ctx.scaleBy(x: 1.08, y: 1.08)
    let head = CGMutablePath()
    head.move(to: CGPoint(x: -56, y: -70))
    head.addCurve(to: CGPoint(x: -180, y: -335), control1: CGPoint(x: -70, y: -170), control2: CGPoint(x: -176, y: -250))
    head.addQuadCurve(to: CGPoint(x: 180, y: -335), control: CGPoint(x: 0, y: -400))
    head.addCurve(to: CGPoint(x: 56, y: -70), control1: CGPoint(x: 176, y: -250), control2: CGPoint(x: 70, y: -170))
    head.closeSubpath()
    let handle = CGPath(roundedRect: CGRect(x: -22, y: -60, width: 44, height: 400), cornerWidth: 22, cornerHeight: 22, transform: nil)
    let band = CGPath(roundedRect: CGRect(x: -98, y: -138, width: 196, height: 84), cornerWidth: 28, cornerHeight: 28, transform: nil)
    // Ombre portée
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 16, height: -26), blur: 38, color: col(0, 0.06, 0.1, 0.55))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(col(1, 1, 1))
    for p in [handle, head, band] { ctx.addPath(p); ctx.fillPath() }
    ctx.endTransparencyLayer()
    ctx.restoreGState()
    // Manche
    ctx.saveGState(); ctx.addPath(handle); ctx.clip()
    ctx.drawLinearGradient(grad([col(0.96, 0.80, 0.55), col(1, 0.96, 0.84), col(0.90, 0.70, 0.44)], [0, 0.4, 1]),
                           start: CGPoint(x: -22, y: 0), end: CGPoint(x: 22, y: 0), options: [])
    ctx.restoreGState()
    // Poils
    ctx.saveGState(); ctx.addPath(head); ctx.clip()
    ctx.drawLinearGradient(grad([col(0.98, 0.58, 0.12), col(1, 0.76, 0.26), col(1, 0.92, 0.55)], [0, 0.5, 1]),
                           start: CGPoint(x: 0, y: -70), end: CGPoint(x: 0, y: -400), options: [])
    ctx.setLineCap(.round)
    for i in -8...8 {
        let t = CGFloat(i)
        ctx.setStrokeColor(col(0.78, 0.40, 0.05, i % 2 == 0 ? 0.30 : 0.15)); ctx.setLineWidth(i % 2 == 0 ? 5 : 3)
        ctx.move(to: CGPoint(x: t * 7, y: -70)); ctx.addLine(to: CGPoint(x: t * 24, y: -410)); ctx.strokePath()
    }
    ctx.drawLinearGradient(grad([col(1, 1, 1, 0.5), col(1, 1, 1, 0)], [0, 1]), start: CGPoint(x: -185, y: -250), end: CGPoint(x: -20, y: -250), options: [])
    ctx.restoreGState()
    // Bague en verre
    ctx.saveGState(); ctx.addPath(band); ctx.clip()
    ctx.drawLinearGradient(grad([col(1, 1, 1, 0.95), col(0.75, 0.97, 0.94, 0.9), col(0.45, 0.85, 0.82, 0.9)], [0, 0.5, 1]),
                           start: CGPoint(x: 0, y: -54), end: CGPoint(x: 0, y: -138), options: [])
    ctx.restoreGState()
    ctx.addPath(band); ctx.setStrokeColor(col(1, 1, 1, 0.7)); ctx.setLineWidth(3); ctx.strokePath()
    ctx.restoreGState()
    sparkle(CGPoint(x: 280, y: 790), 100, col(1, 1, 1), glow: col(0.6, 1, 0.95, 0.9))
    sparkle(CGPoint(x: 790, y: 300), 120, col(1, 1, 1), glow: col(0.6, 1, 0.95, 0.9))
    sparkle(CGPoint(x: 850, y: 520), 46, col(1, 1, 1, 0.9))
}

// Reflet de verre en haut + liseré
ctx.saveGState()
ctx.addPath(squircle); ctx.clip()
ctx.drawLinearGradient(grad([col(1, 1, 1, 0.38), col(1, 1, 1, 0.06), col(1, 1, 1, 0)], [0, 0.35, 0.55]),
                       start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 480), options: [])
ctx.restoreGState()
ctx.restoreGState()
ctx.addPath(squircle); ctx.setStrokeColor(col(1, 1, 1, 0.35)); ctx.setLineWidth(3); ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
