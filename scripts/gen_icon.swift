#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Usage: gen_icon.swift <out.png> [--template] [--size N]
//   default full-color 1024 PNG (squircle + gradient + O + bars)
//   --template   : monochrome black silhouette on transparent (menu bar)
//   --size N     : override pixel size (square)
let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("Usage: gen_icon.swift <out.png> [--template] [--size N]\n".data(using: .utf8)!)
    exit(1)
}
let outPath = args[1]
let isTemplate = args.contains("--template")
let sizeArg: Int? = {
    guard let i = args.firstIndex(of: "--size"), i + 1 < args.count else { return nil }
    return Int(args[i + 1])
}()
let size: CGFloat = CGFloat(sizeArg ?? (isTemplate ? 36 : 1024))
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let rect = CGRect(x: 0, y: 0, width: size, height: size)

if !isTemplate {
    let cornerRadius: CGFloat = size * 0.2237
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    ctx.clip()

    let gradColors = [
        CGColor(red: 0.294, green: 0.349, blue: 0.933, alpha: 1.0),
        CGColor(red: 0.569, green: 0.435, blue: 0.965, alpha: 1.0)
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: size),
        end: CGPoint(x: size, y: 0),
        options: []
    )

    let highlightColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
    ] as CFArray
    let highlight = CGGradient(colorsSpace: colorSpace, colors: highlightColors, locations: [0, 1])!
    ctx.drawRadialGradient(
        highlight,
        startCenter: CGPoint(x: size * 0.3, y: size * 0.75),
        startRadius: 0,
        endCenter: CGPoint(x: size * 0.3, y: size * 0.75),
        endRadius: size * 0.55,
        options: []
    )
}

// Foreground color: white on colored background, black for template
let fg: CGColor = isTemplate
    ? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    : CGColor(red: 1, green: 1, blue: 1, alpha: 1)
ctx.setFillColor(fg)

let center = CGPoint(x: size / 2, y: size / 2)

// Slightly thicker ring for the template (small sizes lose detail)
let outerR: CGFloat = isTemplate ? size * 0.46 : size * 0.33
let innerR: CGFloat = isTemplate ? size * 0.30 : size * 0.23

let outerRect = CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)
let innerRect = CGRect(x: center.x - innerR, y: center.y - innerR, width: innerR * 2, height: innerR * 2)
let ringPath = CGMutablePath()
ringPath.addEllipse(in: outerRect)
ringPath.addEllipse(in: innerRect)
ctx.addPath(ringPath)
ctx.fillPath(using: .evenOdd)

// Waveform bars — only for the full icon. The template at 18pt is too small.
if !isTemplate {
    let barCount = 5
    let barWidth: CGFloat = size * 0.032
    let barGap: CGFloat = size * 0.028
    let totalBarsWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barGap
    let barsStartX = center.x - totalBarsWidth / 2
    let barHeights: [CGFloat] = [0.30, 0.55, 0.85, 0.55, 0.30].map { $0 * (innerR * 1.4) }

    for i in 0..<barCount {
        let x = barsStartX + CGFloat(i) * (barWidth + barGap)
        let h = barHeights[i]
        let y = center.y - h / 2
        let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
        ctx.addPath(CGPath(
            roundedRect: barRect,
            cornerWidth: barWidth / 2,
            cornerHeight: barWidth / 2,
            transform: nil
        ))
        ctx.fillPath()
    }
    ctx.restoreGState()
}

guard let cgImage = ctx.makeImage() else { exit(1) }
let bitmap = NSBitmapImageRep(cgImage: cgImage)
guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }

try png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) (\(png.count) bytes)  size=\(Int(size)) template=\(isTemplate)")
