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
sparkle(center: CGPoint(x: 500, y: 500), r: 300, fill: col(1, 1, 1))
sparkle(center: CGPoint(x: 735, y: 745), r: 105, fill: col(1, 1, 1, 0.95))
sparkle(center: CGPoint(x: 290, y: 255), r: 70, fill: col(1, 1, 1, 0.85))
ctx.restoreGState()

// Fin liseré lumineux
ctx.addPath(squircle); ctx.setStrokeColor(col(1, 1, 1, 0.25)); ctx.setLineWidth(3); ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
