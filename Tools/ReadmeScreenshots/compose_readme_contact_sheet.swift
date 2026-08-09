#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count >= 4 else {
    FileHandle.standardError.write(Data(
        "用法：compose_readme_contact_sheet.swift <output.jpg> <image.webp> <image.webp> [...]\n".utf8
    ))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let inputURLs = CommandLine.arguments.dropFirst(2).map(URL.init(fileURLWithPath:))
let images: [(url: URL, image: NSImage)] = inputURLs.compactMap { url in
    guard let image = NSImage(contentsOf: url) else { return nil }
    return (url, image)
}

guard images.count == inputURLs.count, let firstImage = images.first?.image else {
    FileHandle.standardError.write(Data("无法读取全部联系表输入图片。\n".utf8))
    exit(3)
}

let columns = 3
let rows = Int(ceil(Double(images.count) / Double(columns)))
let landscape = firstImage.size.width > firstImage.size.height
let tileWidth: CGFloat = landscape ? 700 : 360
let imageHeight = round(tileWidth * firstImage.size.height / max(1, firstImage.size.width))
let labelHeight: CGFloat = 34
let gap: CGFloat = 18
let outer: CGFloat = 18
let tileHeight = labelHeight + imageHeight
let canvasSize = NSSize(
    width: outer * 2 + CGFloat(columns) * tileWidth + CGFloat(columns - 1) * gap,
    height: outer * 2 + CGFloat(rows) * tileHeight + CGFloat(max(0, rows - 1)) * gap
)
let canvas = NSImage(size: canvasSize)
canvas.lockFocus()

NSColor(calibratedRed: 0.91, green: 0.95, blue: 0.97, alpha: 1).setFill()
NSRect(origin: .zero, size: canvasSize).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .left
let labelAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.13, alpha: 1),
    .paragraphStyle: paragraph,
]

for (index, item) in images.enumerated() {
    let column = index % columns
    let row = index / columns
    let x = outer + CGFloat(column) * (tileWidth + gap)
    let top = canvasSize.height - outer - CGFloat(row) * (tileHeight + gap)
    let labelRect = NSRect(x: x, y: top - labelHeight, width: tileWidth, height: labelHeight)
    let imageRect = NSRect(x: x, y: top - tileHeight, width: tileWidth, height: imageHeight)

    let label = item.url.deletingPathExtension().lastPathComponent
    label.draw(in: labelRect.insetBy(dx: 4, dy: 7), withAttributes: labelAttributes)

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: imageRect, xRadius: 8, yRadius: 8).addClip()
    item.image.draw(
        in: imageRect,
        from: NSRect(origin: .zero, size: item.image.size),
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 0.28, alpha: 0.24).setStroke()
    let border = NSBezierPath(roundedRect: imageRect, xRadius: 8, yRadius: 8)
    border.lineWidth = 1
    border.stroke()
}

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.84])
else {
    FileHandle.standardError.write(Data("无法编码联系表 JPEG。\n".utf8))
    exit(4)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try jpeg.write(to: outputURL, options: .atomic)
