// Génère l'icône de Besom. Usage : swift scripts/make-icon.swift <sortie.png>
import AppKit
import CoreGraphics

let S: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }
func grad(_ cols: [CGColor], _ locs: [CGFloat]) -> CGGradient { CGGradient(colorsSpace: cs, colors: cols as CFArray, locations: locs)! }

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 184, cornerHeight: 184, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: col(0, 0.2, 0.2, 0.45))
ctx.addPath(squircle); ctx.setFillColor(col(0.1, 0.5, 0.5)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle); ctx.clip()
// Fond menthe → bleu sarcelle
ctx.drawLinearGradient(grad([col(0.10, 0.62, 0.62), col(0.20, 0.78, 0.70), col(0.55, 0.93, 0.78)], [0, 0.55, 1]),
                       start: CGPoint(x: 200, y: 100), end: CGPoint(x: 800, y: 924), options: [])
ctx.drawRadialGradient(grad([col(1, 1, 1, 0.35), col(1, 1, 1, 0)], [0, 1]),
                       startCenter: CGPoint(x: 330, y: 800), startRadius: 0,
                       endCenter: CGPoint(x: 330, y: 800), endRadius: 520, options: [])

// Étoile à quatre branches (scintillement)
func sparkle(center c: CGPoint, r: CGFloat, fill: CGColor) {
    let k = r * 0.16
    let p = CGMutablePath()
    p.move(to: CGPoint(x: c.x, y: c.y + r))
    p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y + k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x + k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y - k))
    p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x - k, y: c.y + k))
    p.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: col(0, 0.25, 0.25, 0.35))
    ctx.addPath(p); ctx.setFillColor(fill); ctx.fillPath()
    ctx.restoreGState()
}
// Balai : dessiné vertical (tête en bas) puis incliné.
func broomPath() -> (head: CGPath, handle: CGPath, band: CGPath) {
    let head = CGMutablePath()
    head.move(to: CGPoint(x: -58, y: -70))
    head.addCurve(to: CGPoint(x: -178, y: -335), control1: CGPoint(x: -75, y: -170), control2: CGPoint(x: -170, y: -250))
    head.addQuadCurve(to: CGPoint(x: 178, y: -335), control: CGPoint(x: 0, y: -395))
    head.addCurve(to: CGPoint(x: 58, y: -70), control1: CGPoint(x: 170, y: -250), control2: CGPoint(x: 75, y: -170))
    head.closeSubpath()
    let handle = CGPath(roundedRect: CGRect(x: -24, y: -60, width: 48, height: 420), cornerWidth: 24, cornerHeight: 24, transform: nil)
    let band = CGPath(roundedRect: CGRect(x: -100, y: -135, width: 200, height: 78), cornerWidth: 26, cornerHeight: 26, transform: nil)
    return (head, handle, band)
}
let parts = broomPath()

ctx.saveGState()
ctx.translateBy(x: 512, y: 520)
ctx.rotate(by: -35 * .pi / 180)

// Ombre portée du balai
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 14, height: -22), blur: 34, color: col(0, 0.22, 0.22, 0.45))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.addPath(parts.handle); ctx.setFillColor(col(1, 1, 1)); ctx.fillPath()
ctx.addPath(parts.head); ctx.fillPath()
ctx.addPath(parts.band); ctx.fillPath()
ctx.endTransparencyLayer()
ctx.restoreGState()

// Manche (bois clair)
ctx.saveGState()
ctx.addPath(parts.handle); ctx.clip()
ctx.drawLinearGradient(grad([col(0.93, 0.74, 0.46), col(1, 0.93, 0.76), col(0.88, 0.66, 0.38)], [0, 0.4, 1]),
                       start: CGPoint(x: -24, y: 0), end: CGPoint(x: 24, y: 0), options: [])
ctx.restoreGState()

// Tête (poils)
ctx.saveGState()
ctx.addPath(parts.head); ctx.clip()
ctx.drawLinearGradient(grad([col(0.96, 0.62, 0.16), col(1, 0.78, 0.30), col(1, 0.90, 0.52)], [0, 0.5, 1]),
                       start: CGPoint(x: 0, y: -70), end: CGPoint(x: 0, y: -395), options: [])
// Brins
ctx.setLineCap(.round)
for i in -7...7 {
    let t = CGFloat(i)
    ctx.setStrokeColor(col(0.80, 0.45, 0.08, i % 2 == 0 ? 0.30 : 0.16))
    ctx.setLineWidth(i % 2 == 0 ? 5 : 3)
    ctx.move(to: CGPoint(x: t * 8, y: -70))
    ctx.addLine(to: CGPoint(x: t * 25, y: -400))
    ctx.strokePath()
}
// Reflet à gauche
ctx.drawLinearGradient(grad([col(1, 1, 1, 0.45), col(1, 1, 1, 0)], [0, 1]),
                       start: CGPoint(x: -180, y: -250), end: CGPoint(x: -20, y: -250), options: [])
ctx.restoreGState()

// Virole (bague de serrage)
ctx.saveGState()
ctx.addPath(parts.band); ctx.clip()
ctx.drawLinearGradient(grad([col(0.04, 0.38, 0.38), col(0.10, 0.52, 0.50), col(0.03, 0.30, 0.31)], [0, 0.45, 1]),
                       start: CGPoint(x: -100, y: -57), end: CGPoint(x: -100, y: -135), options: [])
ctx.restoreGState()
ctx.addPath(parts.band); ctx.setStrokeColor(col(1, 1, 1, 0.3)); ctx.setLineWidth(3); ctx.strokePath()
ctx.restoreGState()

sparkle(center: CGPoint(x: 285, y: 770), r: 95, fill: col(1, 1, 1))
sparkle(center: CGPoint(x: 770, y: 275), r: 115, fill: col(1, 1, 1))
sparkle(center: CGPoint(x: 845, y: 470), r: 48, fill: col(1, 1, 1, 0.9))
ctx.restoreGState()

// Fin liseré lumineux
ctx.addPath(squircle); ctx.setStrokeColor(col(1, 1, 1, 0.25)); ctx.setLineWidth(3); ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
