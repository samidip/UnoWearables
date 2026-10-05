# watchOS render spike (simulator only)

Answers one question: **can a CPU-rasterized pixel buffer reach the watchOS
screen fast enough to host Uno's Skia renderer?**

Result: **yes, and the presentation path is effectively free.** The cost is
entirely in rasterization, which is Skia's existing problem, not a new one.

## What this is not

This does **not** run `MainPage.xaml`, and it contains no .NET. Running Uno's
real renderer needs a Mono runtime pack, targeting pack and bindings built for
`arm64-apple-watchossimulator`; none exist. This spike de-risks the layer
*above* that, so the runtime port can be costed against a known-good target.

CoreGraphics stands in for Skia. Both are CPU rasterizers emitting RGBA8888 --
watchOS exposes no Metal and no OpenGL ES, so a CPU buffer is the only option
for either. The presentation half being measured is identical.

## Architecture

Mirrors Uno's model -- "no native views; a minimal native shell hosts the Skia
surface":

```
state -> SurfaceRenderer.render()      CPU raster into CGContext   (Skia's job)
      -> ctx.makeImage()               pixel buffer -> CGImage     (measured)
      -> Image(decorative:scale:)      SwiftUI presents one bitmap
      -> SpatialTapGesture             location -> hit-test -> state
```

Every pixel, including the FPS HUD, comes from the rasterizer. No SwiftUI view
draws app content.

## Measured (Apple Watch Series 11 46mm, watchOS 26.5 simulator, 416x496px)

| elements | fps  | raster ms | present ms |
|---------:|-----:|----------:|-----------:|
|        0 | 60.0 |      0.88 |      0.060 |
|      100 | 60.0 |      3.65 |      0.035 |
|      400 | 60.4 |      2.96 |      0.010 |
|      800 | 60.0 |      5.49 |      0.015 |
|     1600 | 60.0 |     11.04 |      0.020 |
|     3200 | 44.2 |     21.32 |      0.015 |
|     6400 | 20.0 |     42.52 |      0.020 |

An "element" is one antialiased rounded-rect fill, with a text run every 5th --
the two costs that dominate real XAML.

**Findings**

1. `present` never exceeds 0.06ms and is flat against scene complexity. Getting
   the buffer on screen is O(1) and not a bottleneck. This was the unknown.
2. 60fps holds to ~1600 elements; the 16.7ms budget is exhausted around ~2400.
3. Frame cost is entirely raster. Uno would be trading against Skia's raster
   throughput, which is already well characterised.

## The caveat that matters

**These are Mac numbers.** The simulator runs on the host M-series CPU, not on
Apple S-series watch silicon, which is far slower per core. Treat the element
budget as an upper bound, likely by close to an order of magnitude. The *shape*
of the result transfers (present is free, raster dominates); the absolute
numbers do not. Only a device build settles that -- and a device build needs
the `arm64_32` ILP32 runtime port.

## Incidental findings for a real port

- A standalone watch app needs `WKWatchOnly=true` in Info.plist, or install
  fails demanding `WKCompanionAppBundleIdentifier`.
- `onTapGesture` on watchOS carries **no location**. `SpatialTapGesture` and
  `DragGesture` do, and are what a visual-tree hit-test needs.
- `UIView` and `CALayer` are `API_UNAVAILABLE(watchos)` and absent from the
  `.tbd` exports. There is no layer tree to host a surface -- SwiftUI is the
  only route to the screen.
- Binaries carry `LC_BUILD_VERSION platform WATCHOSSIMULATOR`, so iOS-simulator
  runtime packs cannot be reused even though both are arm64.

## Running it

```bash
./build.sh                                        # build + install
xcrun simctl launch --console-pty <SIM> com.uno.watchrenderspike

# variants (env vars need simctl's SIMCTL_CHILD_ prefix)
SIMCTL_CHILD_SPIKE_SELFTEST=1 xcrun simctl launch --console-pty <SIM> com.uno.watchrenderspike
SIMCTL_CHILD_SPIKE_RAMP=1     xcrun simctl launch --console-pty <SIM> com.uno.watchrenderspike
```

`SPIKE_SELFTEST` drives synthetic hits through the production hit-test path
(simctl cannot inject touches); `SPIKE_RAMP` runs the complexity sweep above.
