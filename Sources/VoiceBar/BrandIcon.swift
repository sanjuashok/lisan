import AppKit

/// The full artwork is used in Settings; the small template stays crisp and
/// follows the menu bar's light/dark appearance at every display scale.
@MainActor
enum BrandIcon {
    static let artwork: NSImage = {
        // The packaged app carries a direct copy so it does not depend on
        // SwiftPM's development-machine resource-bundle lookup paths.
        let url = Bundle.main.url(forResource: "lisan-icon", withExtension: "png")
            ?? Bundle.module.url(forResource: "lisan-icon", withExtension: "png", subdirectory: "Brand")
        guard let url, let image = NSImage(contentsOf: url) else {
            return menuBarImage()
        }
        return image
    }()

    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
            NSGraphicsContext.current?.imageInterpolation = .high
            NSGraphicsContext.current?.shouldAntialias = true
            NSColor.black.set()

            // Seven rounded bars form the globe, matching the full artwork.
            let heights: [CGFloat] = [5.4, 9.8, 12.4, 14.4, 12.4, 9.8, 5.4]
            let barWidth: CGFloat = 1.35
            let spacing: CGFloat = 1.9
            let center = NSPoint(x: 11, y: 9)

            func ringPoint(_ angle: CGFloat) -> NSPoint {
                let x = 10.0 * cos(angle)
                let y = 2.6 * sin(angle)
                let tilt = CGFloat.pi / 8
                return NSPoint(x: center.x + x * cos(tilt) - y * sin(tilt),
                               y: center.y + x * sin(tilt) + y * cos(tilt))
            }

            func orbit(from start: CGFloat, to end: CGFloat) -> NSBezierPath {
                let path = NSBezierPath()
                path.move(to: ringPoint(start))
                for step in 1...64 {
                    path.line(to: ringPoint(start + (end - start) * CGFloat(step) / 64))
                }
                path.lineWidth = 1.1
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                return path
            }

            orbit(from: 0, to: 2 * .pi).stroke()
            for (index, height) in heights.enumerated() {
                let x = center.x + CGFloat(index - 3) * spacing - barWidth / 2
                NSBezierPath(roundedRect: NSRect(x: x, y: center.y - height / 2,
                                                 width: barWidth, height: height),
                             xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
            }

            // A transparent gutter separates the near orbit from the bars.
            let front = orbit(from: .pi, to: 2 * .pi)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            front.lineWidth = 2.6
            front.stroke()
            NSGraphicsContext.restoreGraphicsState()
            NSColor.black.set()
            front.lineWidth = 1.1
            front.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "lisan waveform planet"
        return image
    }
}
