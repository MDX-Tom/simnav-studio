import AppKit
import Foundation

struct IconVariant {
    let assetName: String
    let filePrefix: String
    let webPreviewName: String
    let saturation: CGFloat
    let contrast: CGFloat
    let brightness: CGFloat
    let nightStyle: Bool
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsRoot = root.appendingPathComponent("NavPlanner/Support/Assets.xcassets", isDirectory: true)
let webIconRoot = root.appendingPathComponent("NavPlanner/Resources/Web/app-icons", isDirectory: true)
let sourceURL = root.appendingPathComponent("Tools/Icon/navplanner-terrain-liquid-glass-source.png")

let iconEntries: [(idiom: String, size: String, scale: String, pixels: Int)] = [
    ("iphone", "20x20", "2x", 40),
    ("iphone", "20x20", "3x", 60),
    ("iphone", "29x29", "2x", 58),
    ("iphone", "29x29", "3x", 87),
    ("iphone", "40x40", "2x", 80),
    ("iphone", "40x40", "3x", 120),
    ("iphone", "60x60", "2x", 120),
    ("iphone", "60x60", "3x", 180),
    ("ipad", "20x20", "1x", 20),
    ("ipad", "20x20", "2x", 40),
    ("ipad", "29x29", "1x", 29),
    ("ipad", "29x29", "2x", 58),
    ("ipad", "40x40", "1x", 40),
    ("ipad", "40x40", "2x", 80),
    ("ipad", "76x76", "1x", 76),
    ("ipad", "76x76", "2x", 152),
    ("ipad", "83.5x83.5", "2x", 167),
    ("ios-marketing", "1024x1024", "1x", 1024)
]

// 默认主图标使用日间均衡档；高饱和档不再作为默认，但仍不额外增加源图饱和度。
let variants: [IconVariant] = [
    IconVariant(assetName: "AppIconDayHigh", filePrefix: "day-high", webPreviewName: "day-high", saturation: 1.00, contrast: 1.00, brightness: 0.00, nightStyle: false),
    IconVariant(assetName: "AppIcon", filePrefix: "day-medium", webPreviewName: "day-medium", saturation: 0.58, contrast: 0.90, brightness: 0.020, nightStyle: false),
    IconVariant(assetName: "AppIconDaySoft", filePrefix: "day-soft", webPreviewName: "day-soft", saturation: 0.30, contrast: 0.80, brightness: 0.040, nightStyle: false),
    IconVariant(assetName: "AppIconNightHigh", filePrefix: "night-high", webPreviewName: "night-high", saturation: 1.00, contrast: 1.08, brightness: -0.010, nightStyle: true),
    IconVariant(assetName: "AppIconNightMedium", filePrefix: "night-medium", webPreviewName: "night-medium", saturation: 0.56, contrast: 0.92, brightness: 0.004, nightStyle: true),
    IconVariant(assetName: "AppIconNightSoft", filePrefix: "night-soft", webPreviewName: "night-soft", saturation: 0.28, contrast: 0.80, brightness: 0.018, nightStyle: true)
]

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("无法读取 App 图标源图：\(sourceURL.path)")
}

var processedSourceCache: [String: NSImage] = [:]

func clamp(_ value: CGFloat, min lower: CGFloat = 0, max upper: CGFloat = 1) -> CGFloat {
    Swift.min(upper, Swift.max(lower, value))
}

func drawSourceImage(_ image: NSImage, into destination: NSRect) {
    let sourceSize = image.size
    let sourceSide = min(sourceSize.width, sourceSize.height)
    let sourceRect = NSRect(
        x: (sourceSize.width - sourceSide) / 2,
        y: (sourceSize.height - sourceSide) / 2,
        width: sourceSide,
        height: sourceSide
    )
    image.draw(
        in: destination,
        from: sourceRect,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
}

func processedSourceImage(for variant: IconVariant) -> NSImage {
    if let cached = processedSourceCache[variant.filePrefix] {
        return cached
    }

    let image: NSImage
    if variant.nightStyle {
        image = toneAdjustedImage(from: nightImage(from: sourceImage), variant: variant)
    } else if variant.assetName == "AppIconDayHigh" {
        image = sourceImage
    } else {
        image = toneAdjustedImage(from: sourceImage, variant: variant)
    }

    processedSourceCache[variant.filePrefix] = image
    return image
}

func toneAdjustedImage(from image: NSImage, variant: IconVariant) -> NSImage {
    guard abs(variant.saturation - 1) > 0.001 ||
        abs(variant.contrast - 1) > 0.001 ||
        abs(variant.brightness) > 0.001,
        let tiff = image.tiffRepresentation,
        let sourceRep = NSBitmapImageRep(data: tiff) else {
        return image
    }

    let width = sourceRep.pixelsWide
    let height = sourceRep.pixelsHigh
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: .alphaNonpremultiplied,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return image
    }

    for y in 0..<height {
        for x in 0..<width {
            guard let color = sourceRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            let r = CGFloat(color.redComponent)
            let g = CGFloat(color.greenComponent)
            let b = CGFloat(color.blueComponent)
            let alpha = CGFloat(color.alphaComponent)
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let adjusted = (
                r: clamp(((luma + (r - luma) * variant.saturation) - 0.5) * variant.contrast + 0.5 + variant.brightness),
                g: clamp(((luma + (g - luma) * variant.saturation) - 0.5) * variant.contrast + 0.5 + variant.brightness),
                b: clamp(((luma + (b - luma) * variant.saturation) - 0.5) * variant.contrast + 0.5 + variant.brightness)
            )
            rep.setColor(
                NSColor(deviceRed: adjusted.r, green: adjusted.g, blue: adjusted.b, alpha: alpha),
                atX: x,
                y: y
            )
        }
    }

    let output = NSImage(size: NSSize(width: width, height: height))
    output.addRepresentation(rep)
    return output
}

func nightImage(from image: NSImage) -> NSImage {
    guard let tiff = image.tiffRepresentation,
          let sourceRep = NSBitmapImageRep(data: tiff) else {
        return image
    }

    let width = sourceRep.pixelsWide
    let height = sourceRep.pixelsHigh
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: .alphaNonpremultiplied,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return image
    }

    for y in 0..<height {
        for x in 0..<width {
            guard let color = sourceRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                continue
            }
            let r = CGFloat(color.redComponent)
            let g = CGFloat(color.greenComponent)
            let b = CGFloat(color.blueComponent)
            let alpha = CGFloat(color.alphaComponent)
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let maxChannel = max(r, max(g, b))
            let minChannel = min(r, min(g, b))
            let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
            let blueDominance = b - max(r, g)
            let greenDominance = g - max(r, b)

            let output: NSColor
            if blueDominance > 0.14 && saturation > 0.28 && b > 0.46 && g < 0.72 {
                // 源图中最饱和的蓝色主要来自航路，夜间版改为暗橙色。
                let highlight = clamp((luma - 0.28) / 0.54)
                output = NSColor(
                    deviceRed: clamp(0.40 + highlight * 0.24),
                    green: clamp(0.13 + highlight * 0.10),
                    blue: clamp(0.030 + highlight * 0.050),
                    alpha: alpha
                )
            } else if greenDominance > 0.02 && saturation > 0.08 {
                // 地图里的绿色层次改为紫色层次，保留明暗起伏。
                let depth = clamp(0.22 + (1 - luma) * 0.48)
                output = NSColor(
                    deviceRed: clamp(0.16 + depth * 0.35),
                    green: clamp(0.09 + depth * 0.13),
                    blue: clamp(0.26 + depth * 0.44),
                    alpha: alpha
                )
            } else if blueDominance > 0.02 && saturation > 0.05 {
                // 河流和水域保留为深蓝青，避免和暗橙航路混淆。
                let depth = clamp(0.18 + (1 - luma) * 0.44)
                output = NSColor(
                    deviceRed: clamp(0.03 + depth * 0.08),
                    green: clamp(0.11 + depth * 0.21),
                    blue: clamp(0.21 + depth * 0.36),
                    alpha: alpha
                )
            } else {
                // 类似反色的地形：亮部压成蓝黑，暗部抬成更亮的蓝灰，以保留山体层次。
                let inverseRelief = clamp(0.10 + (1 - luma) * 0.58)
                output = NSColor(
                    deviceRed: clamp(0.015 + inverseRelief * 0.18),
                    green: clamp(0.035 + inverseRelief * 0.22),
                    blue: clamp(0.075 + inverseRelief * 0.38),
                    alpha: alpha
                )
            }
            rep.setColor(output, atX: x, y: y)
        }
    }

    let output = NSImage(size: NSSize(width: width, height: height))
    output.addRepresentation(rep)
    return output
}

func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ size: CGFloat) -> NSRect {
    NSRect(x: x * size, y: y * size, width: w * size, height: h * size)
}

func drawGlassStroke(_ path: NSBezierPath, color: NSColor, width: CGFloat) {
    color.setStroke()
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.lineWidth = width
    path.stroke()
}

func nightRouteGlassPath(size: CGFloat, xOffset: CGFloat = 0, yOffset: CGFloat = 0) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: size * (0.49 + xOffset), y: size * (0.92 + yOffset)))
    path.curve(
        to: NSPoint(x: size * (0.69 + xOffset), y: size * (0.66 + yOffset)),
        controlPoint1: NSPoint(x: size * (0.60 + xOffset), y: size * (0.88 + yOffset)),
        controlPoint2: NSPoint(x: size * (0.78 + xOffset), y: size * (0.80 + yOffset))
    )
    path.curve(
        to: NSPoint(x: size * (0.49 + xOffset), y: size * (0.49 + yOffset)),
        controlPoint1: NSPoint(x: size * (0.62 + xOffset), y: size * (0.57 + yOffset)),
        controlPoint2: NSPoint(x: size * (0.43 + xOffset), y: size * (0.59 + yOffset))
    )
    path.curve(
        to: NSPoint(x: size * (0.61 + xOffset), y: size * (0.18 + yOffset)),
        controlPoint1: NSPoint(x: size * (0.59 + xOffset), y: size * (0.36 + yOffset)),
        controlPoint2: NSPoint(x: size * (0.60 + xOffset), y: size * (0.28 + yOffset))
    )
    return path
}

func terrainGlassPath(size: CGFloat, points: [CGPoint]) -> NSBezierPath {
    let path = NSBezierPath()
    guard let first = points.first else {
        return path
    }
    path.move(to: NSPoint(x: first.x * size, y: first.y * size))
    for point in points.dropFirst() {
        path.line(to: NSPoint(x: point.x * size, y: point.y * size))
    }
    return path
}

func drawNightSubjectGlass(size: CGFloat) {
    let routeGlow = nightRouteGlassPath(size: size, xOffset: -0.004, yOffset: 0.006)
    drawGlassStroke(
        routeGlow,
        color: NSColor(deviceRed: 1.0, green: 0.76, blue: 0.42, alpha: 0.070),
        width: max(1.4, size * 0.0070)
    )

    let routeEdge = nightRouteGlassPath(size: size, xOffset: -0.012, yOffset: 0.010)
    drawGlassStroke(
        routeEdge,
        color: NSColor(calibratedWhite: 1, alpha: 0.145),
        width: max(0.9, size * 0.0026)
    )

    let routeInner = nightRouteGlassPath(size: size, xOffset: 0.013, yOffset: -0.004)
    drawGlassStroke(
        routeInner,
        color: NSColor(deviceRed: 0.98, green: 0.42, blue: 0.13, alpha: 0.085),
        width: max(0.9, size * 0.0030)
    )

    let ridgeSets: [[CGPoint]] = [
        [CGPoint(x: 0.15, y: 0.68), CGPoint(x: 0.25, y: 0.72), CGPoint(x: 0.34, y: 0.70), CGPoint(x: 0.42, y: 0.73)],
        [CGPoint(x: 0.12, y: 0.42), CGPoint(x: 0.24, y: 0.48), CGPoint(x: 0.35, y: 0.46), CGPoint(x: 0.45, y: 0.50)],
        [CGPoint(x: 0.61, y: 0.76), CGPoint(x: 0.72, y: 0.80), CGPoint(x: 0.83, y: 0.78), CGPoint(x: 0.91, y: 0.81)],
        [CGPoint(x: 0.63, y: 0.39), CGPoint(x: 0.73, y: 0.45), CGPoint(x: 0.84, y: 0.43), CGPoint(x: 0.92, y: 0.47)],
        [CGPoint(x: 0.24, y: 0.25), CGPoint(x: 0.34, y: 0.30), CGPoint(x: 0.44, y: 0.28), CGPoint(x: 0.52, y: 0.32)]
    ]

    for ridge in ridgeSets {
        let path = terrainGlassPath(size: size, points: ridge)
        drawGlassStroke(
            path,
            color: NSColor(deviceRed: 0.74, green: 0.84, blue: 1.0, alpha: 0.085),
            width: max(0.9, size * 0.0032)
        )
    }
}

func drawLiquidGlassFinish(size: CGFloat, nightStyle: Bool) {
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = size * 0.030
    let radius = size * 0.190
    let outerPath = NSBezierPath(
        roundedRect: bounds.insetBy(dx: inset, dy: inset),
        xRadius: radius,
        yRadius: radius
    )
    let innerPath = NSBezierPath(
        roundedRect: bounds.insetBy(dx: size * 0.061, dy: size * 0.061),
        xRadius: size * 0.148,
        yRadius: size * 0.148
    )

    NSGraphicsContext.current?.saveGraphicsState()
    outerPath.addClip()

    if nightStyle {
        let localDepth = NSGradient(colors: [
            NSColor(calibratedWhite: 1, alpha: 0.035),
            NSColor(calibratedWhite: 1, alpha: 0.00),
            NSColor(calibratedWhite: 0, alpha: 0.10)
        ])!
        localDepth.draw(in: bounds.insetBy(dx: size * 0.055, dy: size * 0.060), angle: 90)
        drawNightSubjectGlass(size: size)
    } else {
        let topHighlight = NSGradient(colors: [
            NSColor(calibratedWhite: 1, alpha: 0.37),
            NSColor(calibratedWhite: 1, alpha: 0.18),
            NSColor(calibratedWhite: 1, alpha: 0.00)
        ])!
        topHighlight.draw(in: rect(0.055, 0.61, 0.89, 0.34, size), angle: 270)

        let sideSheen = NSGradient(colors: [
            NSColor(calibratedWhite: 1, alpha: 0.23),
            NSColor(calibratedWhite: 1, alpha: 0.00),
            NSColor(calibratedWhite: 1, alpha: 0.12)
        ])!
        sideSheen.draw(in: bounds.insetBy(dx: size * 0.025, dy: size * 0.02), angle: 0)

        let glassVeilPath = NSBezierPath(
            roundedRect: rect(0.075, 0.645, 0.85, 0.22, size),
            xRadius: size * 0.095,
            yRadius: size * 0.095
        )
        let glassVeil = NSGradient(colors: [
            NSColor(calibratedWhite: 1, alpha: 0.18),
            NSColor(calibratedWhite: 1, alpha: 0.065),
            NSColor(calibratedWhite: 1, alpha: 0.00)
        ])!
        glassVeil.draw(in: glassVeilPath, angle: 270)
    }

    let bottomDepth = NSGradient(colors: [
        NSColor(calibratedWhite: 0, alpha: 0.00),
        NSColor(calibratedWhite: 0, alpha: nightStyle ? 0.12 : 0.085)
    ])!
    bottomDepth.draw(in: bounds.insetBy(dx: size * 0.030, dy: size * 0.030), angle: 90)

    NSGraphicsContext.current?.restoreGraphicsState()

    NSColor(calibratedWhite: 0, alpha: nightStyle ? 0.48 : 0.24).setStroke()
    outerPath.lineWidth = max(2.4, size * (nightStyle ? 0.0220 : 0.0150))
    outerPath.stroke()

    NSColor(calibratedWhite: 1, alpha: nightStyle ? 0.60 : 0.52).setStroke()
    outerPath.lineWidth = max(1.8, size * (nightStyle ? 0.0140 : 0.0100))
    outerPath.stroke()

    NSColor(calibratedWhite: 1, alpha: nightStyle ? 0.26 : 0.32).setStroke()
    innerPath.lineWidth = max(1.0, size * 0.0036)
    innerPath.stroke()

    NSColor(calibratedWhite: 0, alpha: nightStyle ? 0.32 : 0.18).setStroke()
    let lowerPath = NSBezierPath(
        roundedRect: bounds.insetBy(dx: size * 0.046, dy: size * 0.047),
        xRadius: size * 0.165,
        yRadius: size * 0.165
    )
    lowerPath.lineWidth = max(0.9, size * 0.0028)
    lowerPath.stroke()

    let glintPath = NSBezierPath()
    glintPath.move(to: NSPoint(x: size * 0.16, y: size * 0.88))
    glintPath.curve(
        to: NSPoint(x: size * 0.66, y: size * 0.92),
        controlPoint1: NSPoint(x: size * 0.28, y: size * 0.96),
        controlPoint2: NSPoint(x: size * 0.50, y: size * 0.96)
    )
    if !nightStyle {
        NSColor(calibratedWhite: 1, alpha: 0.36).setStroke()
        glintPath.lineWidth = max(1.0, size * 0.0025)
        glintPath.stroke()
    }

    let leftGlintPath = NSBezierPath()
    leftGlintPath.move(to: NSPoint(x: size * 0.085, y: size * 0.30))
    leftGlintPath.curve(
        to: NSPoint(x: size * 0.115, y: size * 0.72),
        controlPoint1: NSPoint(x: size * 0.065, y: size * 0.44),
        controlPoint2: NSPoint(x: size * 0.070, y: size * 0.60)
    )
    if !nightStyle {
        NSColor(calibratedWhite: 1, alpha: 0.24).setStroke()
        leftGlintPath.lineWidth = max(0.9, size * 0.0022)
        leftGlintPath.stroke()
    }
}

func renderIcon(size: Int, variant: IconVariant) -> NSImage {
    let outputSize = NSSize(width: size, height: size)
    let image = NSImage(size: outputSize)
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("无法创建 App 图标绘图上下文")
    }
    context.setShouldAntialias(true)
    NSGraphicsContext.current?.imageInterpolation = .high

    let bounds = NSRect(origin: .zero, size: outputSize)
    drawSourceImage(processedSourceImage(for: variant), into: bounds)
    drawLiquidGlassFinish(size: CGFloat(size), nightStyle: variant.nightStyle)

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "NavPlannerIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG 编码失败"])
    }
    try png.write(to: url)
}

func appIconContents(prefix: String) -> Data {
    let images = iconEntries.map { entry -> [String: String] in
        [
            "filename": "\(prefix)-\(entry.idiom)-\(entry.pixels).png",
            "idiom": entry.idiom,
            "scale": entry.scale,
            "size": entry.size
        ]
    }
    let root: [String: Any] = [
        "images": images,
        "info": [
            "author": "xcode",
            "version": 1
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
}

func removeObsoleteOutputs() throws {
    let validAssetNames = Set(variants.map(\.assetName))
    if let assetSets = try? FileManager.default.contentsOfDirectory(at: assetsRoot, includingPropertiesForKeys: nil) {
        for url in assetSets where url.pathExtension == "appiconset" && url.lastPathComponent.hasPrefix("AppIcon") {
            let name = url.deletingPathExtension().lastPathComponent
            if !validAssetNames.contains(name) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    let validPreviewNames = Set(variants.map { "\($0.webPreviewName).png" })
    if let previews = try? FileManager.default.contentsOfDirectory(at: webIconRoot, includingPropertiesForKeys: nil) {
        for url in previews where url.pathExtension == "png" && !validPreviewNames.contains(url.lastPathComponent) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

try FileManager.default.createDirectory(at: assetsRoot, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: webIconRoot, withIntermediateDirectories: true)
try removeObsoleteOutputs()

for variant in variants {
    let setURL = assetsRoot.appendingPathComponent("\(variant.assetName).appiconset", isDirectory: true)
    if FileManager.default.fileExists(atPath: setURL.path) {
        try FileManager.default.removeItem(at: setURL)
    }
    try FileManager.default.createDirectory(at: setURL, withIntermediateDirectories: true)
    for entry in iconEntries {
        let filename = "\(variant.filePrefix)-\(entry.idiom)-\(entry.pixels).png"
        let image = renderIcon(size: entry.pixels, variant: variant)
        try writePNG(image, to: setURL.appendingPathComponent(filename))
    }
    try appIconContents(prefix: variant.filePrefix).write(to: setURL.appendingPathComponent("Contents.json"))
    try writePNG(renderIcon(size: 180, variant: variant), to: webIconRoot.appendingPathComponent("\(variant.webPreviewName).png"))
}

print("已生成日间三档和夜间三档 App 图标；默认主图标为日间均衡。")
