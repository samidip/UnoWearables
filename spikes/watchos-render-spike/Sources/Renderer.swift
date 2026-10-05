import CoreGraphics
import CoreText
import Foundation

/// Models Uno's Skia path on watchOS: rasterize the whole UI into a CPU pixel
/// buffer, then hand one CGImage per frame to the native shell.
///
/// CoreGraphics stands in for Skia here. Both are CPU rasterizers emitting
/// RGBA8888 -- watchOS exposes no Metal/OpenGL, so a CPU buffer is the only
/// option either way. What this measures is the half that was unknown: the
/// cost of getting that buffer onto the screen every frame.
final class SurfaceRenderer {

    struct Metrics {
        var rasterMs: Double = 0   // fill the pixel buffer (Skia's job)
        var presentMs: Double = 0  // buffer -> CGImage (the unknown)
        var fps: Double = 0
    }

    let scale: CGFloat
    private var ctx: CGContext?
    private var pxW = 0, pxH = 0
    private var stamps: [CFAbsoluteTime] = []
    private(set) var metrics = Metrics()
    private var frameCount = 0

    /// Extra vector+text elements per frame, to approximate a real visual tree.
    var stressElements = 0

    init(scale: CGFloat) { self.scale = scale }

    private func ensureContext(size: CGSize) {
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard w > 0, h > 0 else { return }
        if ctx != nil && w == pxW && h == pxH { return }
        pxW = w; pxH = h
        ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                      | CGBitmapInfo.byteOrder32Little.rawValue)
        // Flip to top-left origin so layout matches XAML coordinates.
        ctx?.translateBy(x: 0, y: CGFloat(h))
        ctx?.scaleBy(x: scale, y: -scale)
    }

    func render(count: Int, size: CGSize) -> CGImage? {
        ensureContext(size: size)
        guard let ctx else { return nil }

        let t0 = CFAbsoluteTimeGetCurrent()
        draw(ctx, count: count, size: size)
        let t1 = CFAbsoluteTimeGetCurrent()
        let image = ctx.makeImage()
        let t2 = CFAbsoluteTimeGetCurrent()

        metrics.rasterMs = (t1 - t0) * 1000
        metrics.presentMs = (t2 - t1) * 1000

        stamps.append(t2)
        if stamps.count > 30 { stamps.removeFirst() }
        if stamps.count > 1, let f = stamps.first, let l = stamps.last, l > f {
            metrics.fps = Double(stamps.count - 1) / (l - f)
        }

        frameCount += 1
        if frameCount % 30 == 0 {
            print(String(format: "[spike] elements=%4d fps=%5.1f raster=%6.2fms present=%.2fms",
                         stressElements, metrics.fps, metrics.rasterMs, metrics.presentMs))
        }
        return image
    }

    // MARK: - MainPage.xaml, drawn entirely in the rasterizer.

    /// Button hit rect in points; the shell routes taps against this.
    static func buttonRect(in size: CGSize) -> CGRect {
        CGRect(x: 16, y: size.height / 2 - 18, width: size.width - 32, height: 36)
    }

    private func draw(_ ctx: CGContext, count: Int, size: CGSize) {
        ctx.setFillColor(CGColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1))
        ctx.fill(CGRect(origin: .zero, size: size))

        drawStress(ctx, size: size)

        let cx = size.width / 2

        text("Hello Uno Platform!", at: CGPoint(x: cx, y: size.height / 2 - 46),
             size: 15, weight: "HelveticaNeue-Medium",
             color: CGColor(red: 1, green: 1, blue: 1, alpha: 1), ctx: ctx)

        let btn = Self.buttonRect(in: size)
        let path = CGPath(roundedRect: btn, cornerWidth: 18, cornerHeight: 18, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(CGColor(red: 0.27, green: 0.50, blue: 0.96, alpha: 1))
        ctx.fillPath()
        text("Increment Counter", at: CGPoint(x: cx, y: btn.midY),
             size: 14, weight: "HelveticaNeue-Medium",
             color: CGColor(red: 1, green: 1, blue: 1, alpha: 1), ctx: ctx)

        text("Counter: \(count)", at: CGPoint(x: cx, y: size.height / 2 + 46),
             size: 17, weight: "HelveticaNeue-Bold",
             color: CGColor(red: 1, green: 1, blue: 1, alpha: 1), ctx: ctx)

        // HUD, also rasterized -- no native views anywhere in this frame.
        text(String(format: "%.0f fps  r%.1f p%.1f", metrics.fps, metrics.rasterMs, metrics.presentMs),
             at: CGPoint(x: cx, y: size.height - 14),
             size: 10, weight: "HelveticaNeue",
             color: CGColor(red: 0.45, green: 0.85, blue: 0.45, alpha: 1), ctx: ctx)
    }

    /// Approximates an Uno visual tree: antialiased rounded-rect fills with a
    /// text run every 5th element -- the two costs that dominate real XAML.
    private func drawStress(_ ctx: CGContext, size: CGSize) {
        guard stressElements > 0 else { return }
        for i in 0..<stressElements {
            let f = CGFloat(i)
            let r = CGRect(x: (f * 13).truncatingRemainder(dividingBy: max(size.width - 24, 1)),
                           y: (f * 7).truncatingRemainder(dividingBy: max(size.height - 16, 1)),
                           width: 24, height: 14)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: 4, cornerHeight: 4, transform: nil))
            ctx.setFillColor(CGColor(red: (f / 255).truncatingRemainder(dividingBy: 1),
                                     green: 0.3, blue: 0.5, alpha: 0.5))
            ctx.fillPath()
            if i % 5 == 0 {
                text("\(i)", at: CGPoint(x: r.midX, y: r.midY), size: 8,
                     weight: "HelveticaNeue",
                     color: CGColor(red: 1, green: 1, blue: 1, alpha: 0.6), ctx: ctx)
            }
        }
    }

    private func text(_ s: String, at center: CGPoint, size: CGFloat,
                      weight: String, color: CGColor, ctx: CGContext) {
        let font = CTFontCreateWithName(weight as CFString, size, nil)
        let attrs = [kCTFontAttributeName: font,
                     kCTForegroundColorAttributeName: color] as CFDictionary
        guard let s = CFAttributedStringCreate(nil, s as CFString, attrs) else { return }
        let line = CTLineCreateWithAttributedString(s)
        let b = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        ctx.saveGState()
        ctx.textMatrix = .identity
        ctx.translateBy(x: center.x - b.width / 2, y: center.y + b.height / 2)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
