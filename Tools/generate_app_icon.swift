// Generates the macOS app icon (AppIcon.iconset) with CoreGraphics — no
// external rasterizer needed. Usage: swift generate_app_icon.swift <out-iconset-dir>
import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let design: CGFloat = 1024

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawIcon(_ ctx: CGContext) {
    let s = design

    // Background squircle with the AWS gradient.
    let margin = s * 0.055
    let bg = CGRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let bgPath = rounded(bg, (s - 2 * margin) * 0.2237)

    ctx.saveGState()
    ctx.addPath(bgPath); ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [rgb(255, 165, 20), rgb(35, 47, 62)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: margin, y: s - margin),
        end: CGPoint(x: s - margin, y: margin),
        options: []
    )
    // Soft top-left sheen.
    ctx.setFillColor(rgb(255, 255, 255, 0.10))
    ctx.fillEllipse(in: CGRect(x: -s * 0.1, y: s * 0.45, width: s * 0.9, height: s * 0.8))
    ctx.restoreGState()

    // Profile cards, centered, with a back stack to imply "multiple profiles".
    let cardW = s * 0.50
    let cardH = s * 0.345
    let cx = s / 2, cy = s * 0.50
    let radius = s * 0.038

    func card(dx: CGFloat, dy: CGFloat, scale: CGFloat, fill: CGColor) {
        let w = cardW * scale, h = cardH * scale
        ctx.addPath(rounded(CGRect(x: cx - w / 2 + dx, y: cy - h / 2 + dy, width: w, height: h), radius))
        ctx.setFillColor(fill); ctx.fillPath()
    }

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.010), blur: s * 0.03, color: rgb(0, 0, 0, 0.28))
    card(dx: -s * 0.045, dy: s * 0.075, scale: 0.92, fill: rgb(255, 255, 255, 0.45))
    card(dx: -s * 0.020, dy: s * 0.038, scale: 0.96, fill: rgb(255, 255, 255, 0.70))
    card(dx: 0, dy: 0, scale: 1.0, fill: rgb(255, 255, 255, 1))
    ctx.restoreGState()

    let front = CGRect(x: cx - cardW / 2, y: cy - cardH / 2, width: cardW, height: cardH)
    let pad = cardW * 0.10

    // Avatar (AWS orange) top-left.
    let aD = cardH * 0.34
    let avatar = CGRect(x: front.minX + pad, y: front.maxY - pad - aD, width: aD, height: aD)
    ctx.setFillColor(rgb(255, 153, 0)); ctx.fillEllipse(in: avatar)

    // Text lines.
    let lineX = avatar.maxX + cardW * 0.06
    let lineW = front.maxX - pad - lineX
    func bar(_ rect: CGRect, _ color: CGColor) { ctx.addPath(rounded(rect, rect.height / 2)); ctx.setFillColor(color); ctx.fillPath() }
    bar(CGRect(x: lineX, y: avatar.midY + cardH * 0.015, width: lineW, height: cardH * 0.085), rgb(45, 55, 72, 0.9))
    bar(CGRect(x: lineX, y: avatar.midY - cardH * 0.13, width: lineW * 0.66, height: cardH * 0.07), rgb(150, 160, 175, 0.85))
    bar(CGRect(x: front.minX + pad, y: front.minY + cardH * 0.17, width: cardW - 2 * pad, height: cardH * 0.075), rgb(205, 212, 222, 0.95))

    // Green "default" check badge at the bottom-right corner of the front card.
    let bD = cardH * 0.42
    let bc = CGPoint(x: front.maxX - bD * 0.10, y: front.minY + bD * 0.10)
    let badge = CGRect(x: bc.x - bD / 2, y: bc.y - bD / 2, width: bD, height: bD)
    ctx.setFillColor(rgb(255, 255, 255)); ctx.fillEllipse(in: badge.insetBy(dx: -bD * 0.09, dy: -bD * 0.09))
    ctx.setFillColor(rgb(46, 196, 113)); ctx.fillEllipse(in: badge)
    ctx.setStrokeColor(rgb(255, 255, 255))
    ctx.setLineWidth(bD * 0.13); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: bc.x - bD * 0.21, y: bc.y - bD * 0.01))
    ctx.addLine(to: CGPoint(x: bc.x - bD * 0.04, y: bc.y - bD * 0.17))
    ctx.addLine(to: CGPoint(x: bc.x + bD * 0.23, y: bc.y + bD * 0.18))
    ctx.strokePath()
}

func renderPNG(pixels: Int, to url: URL) {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let scale = CGFloat(pixels) / design
    ctx.scaleBy(x: scale, y: scale)
    drawIcon(ctx)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, px) in entries {
    renderPNG(pixels: px, to: URL(fileURLWithPath: outDir).appendingPathComponent(name))
}
print("Wrote \(entries.count) PNGs to \(outDir)")
