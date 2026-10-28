// Génère docs/social-preview.png (1280×640), image de partage GitHub. Usage : swift scripts/make-social.swift <sortie.png>
import AppKit
import CoreGraphics

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/social-preview.png"
let W: CGFloat = 1280, H: CGFloat = 640
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }
func grad(_ c: [CGColor], _ l: [CGFloat]) -> CGGradient { CGGradient(colorsSpace: cs, colors: c as CFArray, locations: l)! }

ctx.drawLinearGradient(grad([col(0.06, 0.10, 0.30), col(0.10, 0.30, 0.62), col(0.22, 0.62, 0.90)], [0, 0.55, 1]),
                       start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])
ctx.drawRadialGradient(grad([col(0.55, 0.9, 1, 0.45), col(0.55, 0.9, 1, 0)], [0, 1]), startCenter: CGPoint(x: 1050, y: 560), startRadius: 0,
                       endCenter: CGPoint(x: 1050, y: 560), endRadius: 520, options: [])

let icon = NSImage(contentsOfFile: "Resources/AppIcon-1024.png")!
ctx.saveGState()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
icon.draw(in: NSRect(x: 90, y: 120, width: 400, height: 400))
let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 120, weight: .bold), .foregroundColor: NSColor.white]
let sub: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 40, weight: .medium), .foregroundColor: NSColor(white: 1, alpha: 0.9)]
let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 28, weight: .regular), .foregroundColor: NSColor(white: 1, alpha: 0.7)]
("Besom" as NSString).draw(at: CGPoint(x: 520, y: 345), withAttributes: title)
("Passe le balai sur ton Mac." as NSString).draw(at: CGPoint(x: 526, y: 285), withAttributes: sub)
("Caches · Temporaires · Orphelins · Corbeille" as NSString).draw(at: CGPoint(x: 526, y: 225), withAttributes: small)
("Graphique du stockage · macOS 14+" as NSString).draw(at: CGPoint(x: 526, y: 180), withAttributes: small)
NSGraphicsContext.restoreGraphicsState()
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
