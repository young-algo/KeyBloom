import Foundation
import AppKit
import CoreGraphics

// KeyBloom App Icon Generator (Revised Task 1)
// Generates standard macOS multi-resolution AppIcon assets and AppIcon.icns deterministically.
// Designed for maximum Dock legibility: high-contrast tactile keycap with broad upper-hemisphere bloom.

func cgColor(_ hex: String, alpha: CGFloat = 1.0) -> CGColor {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
    var rgb: UInt64 = 0
    Scanner(string: hexSanitized).scanHexInt64(&rgb)
    let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
    let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
    let b = CGFloat(rgb & 0x0000FF) / 255.0
    return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, alpha])!
}

func createGradient(colors: [CGColor], locations: [CGFloat]) -> CGGradient {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    return CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

func createPetalPath(cx: CGFloat, cy: CGFloat, length: CGFloat, width: CGFloat, angle: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let cosA = cos(angle)
    let sinA = sin(angle)
    let perpA = angle + .pi / 2
    let cosP = cos(perpA)
    let sinP = sin(perpA)
    
    let tipX = cx + length * cosA
    let tipY = cy + length * sinA
    let halfW = width * 0.5
    
    // Broad organic petal control points
    let ctrlLeft1 = CGPoint(x: cx + (length * 0.22) * cosA + (halfW * 0.98) * cosP,
                            y: cy + (length * 0.22) * sinA + (halfW * 0.98) * sinP)
    let ctrlLeft2 = CGPoint(x: tipX - (length * 0.25) * cosA + (halfW * 0.40) * cosP,
                            y: tipY - (length * 0.25) * sinA + (halfW * 0.40) * sinP)
    
    let ctrlRight1 = CGPoint(x: tipX - (length * 0.25) * cosA - (halfW * 0.40) * cosP,
                             y: tipY - (length * 0.25) * sinA - (halfW * 0.40) * sinP)
    let ctrlRight2 = CGPoint(x: cx + (length * 0.22) * cosA - (halfW * 0.98) * cosP,
                             y: cy + (length * 0.22) * sinA - (halfW * 0.98) * sinP)
    
    path.move(to: CGPoint(x: cx, y: cy))
    path.addCurve(to: CGPoint(x: tipX, y: tipY), control1: ctrlLeft1, control2: ctrlLeft2)
    path.addCurve(to: CGPoint(x: cx, y: cy), control1: ctrlRight1, control2: ctrlRight2)
    path.closeSubpath()
    
    return path
}

func drawMasterIcon(context: CGContext) {
    // -------------------------------------------------------------
    // 1. macOS Continuous Squircle Tile & Backdrop
    // -------------------------------------------------------------
    let tileRect = CGRect(x: 101, y: 101, width: 822, height: 822)
    let squircleRadius: CGFloat = 184
    let squirclePath = CGPath(roundedRect: tileRect, cornerWidth: squircleRadius, cornerHeight: squircleRadius, transform: nil)
    
    // 1a. Tile Drop Shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 28, color: cgColor("#000000", alpha: 0.44))
    context.setFillColor(cgColor("#090518"))
    context.addPath(squirclePath)
    context.fillPath()
    context.restoreGState()
    
    // Clip drawing to squircle tile
    context.saveGState()
    context.addPath(squirclePath)
    context.clip()
    
    // 1b. Deep Navy-to-Purple Tile Gradient
    let tileGradient = createGradient(
        colors: [
            cgColor("#201648"), // top-left midnight purple
            cgColor("#130C30"), // center deep navy indigo
            cgColor("#090518")  // bottom-right obsidian abyss
        ],
        locations: [0.0, 0.5, 1.0]
    )
    context.drawLinearGradient(
        tileGradient,
        start: CGPoint(x: 101, y: 923),
        end: CGPoint(x: 923, y: 101),
        options: []
    )
    
    // 1c. Ambient Backdrop Glow behind bloom
    let ambientCenter = CGPoint(x: 512, y: 460)
    let ambientGlow = createGradient(
        colors: [
            cgColor("#E01A4F", alpha: 0.24),
            cgColor("#00F2FE", alpha: 0.14),
            cgColor("#130C30", alpha: 0.0)
        ],
        locations: [0.0, 0.45, 1.0]
    )
    context.drawRadialGradient(
        ambientGlow,
        startCenter: ambientCenter,
        startRadius: 0,
        endCenter: ambientCenter,
        endRadius: 400,
        options: []
    )
    
    // -------------------------------------------------------------
    // 2. High-Contrast Tactile Keycap (Lower Tile: Y=140 to Y=420)
    // -------------------------------------------------------------
    let keyBaseRect = CGRect(x: 262, y: 140, width: 500, height: 320)
    let keyBaseRadius: CGFloat = 44
    let keyBasePath = CGPath(roundedRect: keyBaseRect, cornerWidth: keyBaseRadius, cornerHeight: keyBaseRadius, transform: nil)
    
    // 2a. Key Base Shadow
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: cgColor("#000000", alpha: 0.55))
    context.setFillColor(cgColor("#0F0B1E"))
    context.addPath(keyBasePath)
    context.fillPath()
    context.restoreGState()
    
    // 2b. Key Base Fill (Beveled Sides)
    let keyBaseGradient = createGradient(
        colors: [
            cgColor("#3A315E"),
            cgColor("#241C42"),
            cgColor("#16102E")
        ],
        locations: [0.0, 0.5, 1.0]
    )
    context.saveGState()
    context.addPath(keyBasePath)
    context.clip()
    context.drawLinearGradient(keyBaseGradient, start: CGPoint(x: 512, y: 460), end: CGPoint(x: 512, y: 140), options: [])
    context.restoreGState()
    
    // 2c. Key Top Face (Recessed Concave Dish: Y=185 to Y=420)
    let keyTopRect = CGRect(x: 292, y: 185, width: 440, height: 235)
    let keyTopRadius: CGFloat = 36
    let keyTopPath = CGPath(roundedRect: keyTopRect, cornerWidth: keyTopRadius, cornerHeight: keyTopRadius, transform: nil)
    
    // High-Contrast Slate-Periwinkle Top Dish Face (>2.5:1 contrast against background)
    let keyTopGradient = createGradient(
        colors: [
            cgColor("#8A80B8"), // top edge lit
            cgColor("#665B96"), // mid dish surface
            cgColor("#4B3F78")  // bottom edge shadowed
        ],
        locations: [0.0, 0.5, 1.0]
    )
    context.saveGState()
    context.addPath(keyTopPath)
    context.clip()
    context.drawLinearGradient(keyTopGradient, start: CGPoint(x: 512, y: 420), end: CGPoint(x: 512, y: 185), options: [])
    context.restoreGState()
    
    // Crisp Specular Rim Light around Key Top Face
    context.saveGState()
    context.addPath(keyTopPath)
    context.setLineWidth(3.0)
    context.setStrokeColor(cgColor("#C8D6FF", alpha: 0.75))
    context.strokePath()
    context.restoreGState()
    
    // -------------------------------------------------------------
    // 3. Broad Upper-Hemisphere Flower Bloom Burst (Y=420 to Y=780)
    // -------------------------------------------------------------
    let bloomCenter = CGPoint(x: 512, y: 420)
    
    // Layer 1: Broad Outer Electric Cyan Petals (5 petals, upper hemisphere + 2 side flanking)
    let outerAngles: [CGFloat] = [
        .pi * 0.50, // 90°  - straight up
        .pi * 0.35, // 63°  - upper right
        .pi * 0.65, // 117° - upper left
        .pi * 0.14, // 25°  - side flanking right
        .pi * 0.86  // 155° - side flanking left
    ]
    let outerLengths: [CGFloat] = [340, 310, 310, 220, 220]
    let outerWidths: [CGFloat]  = [145, 135, 135, 110, 110]
    
    let cyanGradient = createGradient(
        colors: [
            cgColor("#FF0844"), // warm magenta center
            cgColor("#00E5FF"), // electric turquoise mid
            cgColor("#0077FF")  // deep cyan tip
        ],
        locations: [0.0, 0.5, 1.0]
    )
    
    for i in 0..<outerAngles.count {
        let angle = outerAngles[i]
        let length = outerLengths[i]
        let width = outerWidths[i]
        
        let petalPath = createPetalPath(cx: bloomCenter.x, cy: bloomCenter.y, length: length, width: width, angle: angle)
        
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: cgColor("#000000", alpha: 0.38))
        context.addPath(petalPath)
        context.clip()
        
        let tipX = bloomCenter.x + length * cos(angle)
        let tipY = bloomCenter.y + length * sin(angle)
        context.drawLinearGradient(cyanGradient, start: bloomCenter, end: CGPoint(x: tipX, y: tipY), options: [])
        context.restoreGState()
    }
    
    // Layer 2: Broad Inner Hot Pink / Solar Yellow Petals (3 upper petals)
    let innerAngles: [CGFloat] = [
        .pi * 0.50, // 90°  - straight up inner
        .pi * 0.38, // 68°  - upper right inner
        .pi * 0.62  // 112° - upper left inner
    ]
    let innerLengths: [CGFloat] = [230, 200, 200]
    let innerWidths: [CGFloat]  = [115, 100, 100]
    
    let magentaGradient = createGradient(
        colors: [
            cgColor("#FFD200"), // solar yellow center
            cgColor("#FF0844"), // hot neon magenta
            cgColor("#C80058")  // rose tip
        ],
        locations: [0.0, 0.45, 1.0]
    )
    
    for i in 0..<innerAngles.count {
        let angle = innerAngles[i]
        let length = innerLengths[i]
        let width = innerWidths[i]
        
        let petalPath = createPetalPath(cx: bloomCenter.x, cy: bloomCenter.y, length: length, width: width, angle: angle)
        
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -4), blur: 8, color: cgColor("#000000", alpha: 0.30))
        context.addPath(petalPath)
        context.clip()
        
        let tipX = bloomCenter.x + length * cos(angle)
        let tipY = bloomCenter.y + length * sin(angle)
        context.drawLinearGradient(magentaGradient, start: bloomCenter, end: CGPoint(x: tipX, y: tipY), options: [])
        context.restoreGState()
    }
    
    // Luminous Core Center
    context.saveGState()
    let coreGlow = createGradient(
        colors: [cgColor("#FFFFFF", alpha: 1.0), cgColor("#FFE600", alpha: 0.95), cgColor("#FF0844", alpha: 0.0)],
        locations: [0.0, 0.45, 1.0]
    )
    context.drawRadialGradient(coreGlow, startCenter: bloomCenter, startRadius: 0, endCenter: bloomCenter, endRadius: 75, options: [])
    
    let coreWhite = CGPath(ellipseIn: CGRect(x: bloomCenter.x - 26, y: bloomCenter.y - 26, width: 52, height: 52), transform: nil)
    context.setFillColor(cgColor("#FFFFFF"))
    context.addPath(coreWhite)
    context.fillPath()
    context.restoreGState()
    
    // -------------------------------------------------------------
    // 4. Squircle Inner Rim Highlight
    // -------------------------------------------------------------
    context.saveGState()
    context.addPath(squirclePath)
    context.setLineWidth(2.5)
    context.setStrokeColor(cgColor("#FFFFFF", alpha: 0.22))
    context.strokePath()
    context.restoreGState()
    
    context.restoreGState()
}

func renderIconImage(pixelSize: Int) -> CGImage? {
    let width = pixelSize
    let height = pixelSize
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else { return nil }
    
    let scale = CGFloat(pixelSize) / 1024.0
    context.scaleBy(x: scale, y: scale)
    
    drawMasterIcon(context: context)
    
    return context.makeImage()
}

func savePNG(_ image: CGImage, to url: URL) -> Bool {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    do {
        try data.write(to: url)
        return true
    } catch {
        print("Error saving PNG to \(url.path): \(error)")
        return false
    }
}

func main() {
    let scriptPath = URL(fileURLWithPath: #filePath)
    let projectRoot = scriptPath.deletingLastPathComponent().deletingLastPathComponent()
    let assetsDir = projectRoot.appendingPathComponent("Assets")
    let iconsetDir = assetsDir.appendingPathComponent("AppIcon.iconset")
    let icnsURL = assetsDir.appendingPathComponent("AppIcon.icns")
    let pngPreviewURL = assetsDir.appendingPathComponent("AppIcon.png")
    
    let fm = FileManager.default
    
    // Fix 5a: Pre-clean AppIcon.iconset directory before generation
    if fm.fileExists(atPath: iconsetDir.path) {
        do {
            try fm.removeItem(at: iconsetDir)
        } catch {
            print("Warning: Failed to clean pre-existing iconset dir: \(error)")
        }
    }
    
    do {
        try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true, attributes: nil)
    } catch {
        print("Failed to create iconset directory: \(error)")
        exit(1)
    }
    
    let iconSpecs: [(name: String, size: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]
    
    print("🎨 Rendering KeyBloom App Icon assets (Revised Legibility Design)...")
    
    // Fix 6: Cache duplicate pixel dimensions
    var imageCache = [Int: CGImage]()
    
    func getImage(forSize size: Int) -> CGImage? {
        if let cached = imageCache[size] {
            return cached
        }
        guard let rendered = renderIconImage(pixelSize: size) else { return nil }
        imageCache[size] = rendered
        return rendered
    }
    
    guard let masterImage = getImage(forSize: 1024) else {
        print("Error: Failed to render 1024x1024 master icon.")
        exit(1)
    }
    
    // Save 1024px PNG preview/source
    if !savePNG(masterImage, to: pngPreviewURL) {
        print("Error saving 1024px PNG preview.")
        exit(1)
    }
    print(" Saved 1024px PNG preview to \(pngPreviewURL.path)")
    
    for spec in iconSpecs {
        let destURL = iconsetDir.appendingPathComponent(spec.name)
        guard let validImg = getImage(forSize: spec.size), savePNG(validImg, to: destURL) else {
            print("Error rendering \(spec.name)")
            exit(1)
        }
        print(" Generated \(spec.name) (\(spec.size)x\(spec.size) px)")
    }
    
    print("🔨 Converting iconset to AppIcon.icns with iconutil...")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
    
    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            print("Error: iconutil exited with code \(process.terminationStatus)")
            exit(1)
        }
    } catch {
        print("Error executing iconutil: \(error)")
        exit(1)
    }
    
    print("✨ Successfully generated \(icnsURL.path)")
    
    // Fix 5b: Remove temporary AppIcon.iconset directory post-conversion
    do {
        try fm.removeItem(at: iconsetDir)
        print("🧹 Cleaned up temporary iconset folder \(iconsetDir.path)")
    } catch {
        print("Warning: Failed to remove temporary iconset folder: \(error)")
    }
}

main()
