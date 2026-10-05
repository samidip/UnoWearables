import SwiftUI
import WatchKit

/// The "minimal native shell" from Uno's Skia architecture: it owns no UI of
/// its own. It hands the rasterizer a size, presents the resulting CGImage,
/// and routes input back. Every pixel on screen comes from the pixel buffer.
@main
struct WatchRenderSpikeApp: App {
    var body: some Scene {
        WindowGroup { ShellView() }
    }
}

struct ShellView: View {
    // @State so the renderer (and its cached CGContext) survives body
    // re-evaluation -- a plain `let` would reallocate the surface every frame.
    @State private var renderer = SurfaceRenderer(scale: WKInterfaceDevice.current().screenScale)
    @State private var count = 0
    @State private var lastSize: CGSize = .zero
    @State private var selfTest: Timer?

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { _ in
                surface(geo.size)
            }
            .onAppear {
                lastSize = geo.size
                if ProcessInfo.processInfo.environment["SPIKE_SELFTEST"] != nil {
                    startSelfTest()
                }
                if ProcessInfo.processInfo.environment["SPIKE_RAMP"] != nil {
                    startRamp()
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func surface(_ size: CGSize) -> some View {
        if let frame = renderer.render(count: count, size: size) {
            Image(decorative: frame, scale: renderer.scale)
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(
                    // onTapGesture carries no location on watchOS; SpatialTapGesture
                    // does, which is what a real hit-test against the visual tree needs.
                    SpatialTapGesture().onEnded { hit in
                        dispatch(hit.location, in: size)
                    }
                )
        } else {
            Color.black
        }
    }

    /// Single entry point for input. The real gesture and the self-test both
    /// go through here, so the self-test exercises the production hit-test.
    private func dispatch(_ location: CGPoint, in size: CGSize) {
        let target = SurfaceRenderer.buttonRect(in: size)
        if target.contains(location) {
            count += 1
            print(String(format: "[spike] hit  ACCEPT (%.0f,%.0f) -> count=%d", location.x, location.y, count))
        } else {
            print(String(format: "[spike] hit  REJECT (%.0f,%.0f) -- outside button", location.x, location.y))
        }
    }

    /// Ramps scene complexity to find the CPU-raster budget: how many
    /// antialiased elements fit in a frame before the surface drops below 60
    /// and then 30 fps.
    private func startRamp() {
        let steps = [0, 25, 50, 100, 200, 400, 800, 1600, 3200, 6400]
        var i = 0
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { t in
            guard i < steps.count else {
                print("[spike] ramp complete")
                t.invalidate()
                return
            }
            renderer.stressElements = steps[i]
            i += 1
        }
    }

    /// Alternates an inside-button and outside-button synthetic hit so the
    /// console proves the hit-test both accepts and rejects.
    private func startSelfTest() {
        var inside = true
        selfTest = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            let size = lastSize
            guard size != .zero else { return }
            let btn = SurfaceRenderer.buttonRect(in: size)
            let p = inside ? CGPoint(x: btn.midX, y: btn.midY)
                           : CGPoint(x: btn.midX, y: btn.minY - 30)
            dispatch(p, in: size)
            inside.toggle()
        }
    }
}
