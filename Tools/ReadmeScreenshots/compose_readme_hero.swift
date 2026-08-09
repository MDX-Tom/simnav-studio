#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data("用法：compose_readme_hero.swift <iphone.webp> <ipad.webp> <output.png>\n".utf8))
    exit(2)
}

let phoneURL = URL(fileURLWithPath: CommandLine.arguments[1])
let padURL = URL(fileURLWithPath: CommandLine.arguments[2])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])
guard let phoneImage = NSImage(contentsOf: phoneURL),
      let padImage = NSImage(contentsOf: padURL)
else {
    FileHandle.standardError.write(Data("无法读取亮色 README 截图。\n".utf8))
    exit(3)
}

let canvasSize = NSSize(width: 1450, height: 900)
let canvas = NSImage(size: canvasSize)
canvas.lockFocus()

let backgroundRect = NSRect(origin: .zero, size: canvasSize)
NSGradient(colors: [
    NSColor(calibratedRed: 0.91, green: 0.97, blue: 0.99, alpha: 1),
    NSColor(calibratedRed: 0.78, green: 0.89, blue: 0.95, alpha: 1),
])?.draw(in: backgroundRect, angle: -18)

func drawScreenshot(_ image: NSImage, in rect: NSRect, cornerRadius: CGFloat, shadowRadius: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0.10, alpha: 0.28)
    shadow.shadowBlurRadius = shadowRadius
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()

    NSColor(calibratedWhite: 1, alpha: 0.94).setFill()
    NSBezierPath(roundedRect: rect.insetBy(dx: -7, dy: -7), xRadius: cornerRadius + 7, yRadius: cornerRadius + 7).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
    image.draw(in: rect, from: NSRect(origin: .zero, size: image.size), operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

// 亮色 iPad 横屏作为工作台主体，iPhone 竖屏在左前方；两台设备均完整保留。
drawScreenshot(
    padImage,
    in: NSRect(x: 305, y: 66, width: 1100, height: 825),
    cornerRadius: 26,
    shadowRadius: 24
)
drawScreenshot(
    phoneImage,
    in: NSRect(x: 54, y: 76, width: 340, height: 739),
    cornerRadius: 42,
    shadowRadius: 28
)

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("无法编码 hero PNG。\n".utf8))
    exit(4)
}
try png.write(to: outputURL, options: .atomic)
