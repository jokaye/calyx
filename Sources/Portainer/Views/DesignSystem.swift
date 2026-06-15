import AppKit
import QuartzCore
import SwiftUI

enum AppTheme {
    static let ink = Color(hex: 0x0C234B)
    static let muted = Color(hex: 0x53627B)
    static let blue = Color(hex: 0x255DFF)
    static let cyan = Color(hex: 0x18BFAE)
    static let violet = Color(hex: 0x8F49FF)
    static let red = Color(hex: 0xF0445E)
    static let canvas = Color(hex: 0xF3F7FF)
    static let surface = Color(hex: 0xF8FBFF)
    static let surfaceRaised = Color(hex: 0xFFFFFF)
    static let surfaceSelected = Color(hex: 0xDDE8FF)
    static let panelStroke = Color.white.opacity(0.30)
    static let separator = Color(hex: 0x8EA3C8, alpha: 0.18)

    static let coreInk = Color(hex: 0xEFF7FF)
    static let coreMuted = Color(hex: 0xA8B9CF)
    static let coreGlass = Color(hex: 0x0B1623)
    static let coreGlassRaised = Color(hex: 0x132437)
    static let coreStroke = Color(hex: 0xC4DEFF, alpha: 0.16)
}

struct AppBackground: View {
    var body: some View {
        AppTheme.canvas.opacity(0.10)
            .background(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        Color(hex: 0xEEF4FF, alpha: 0.30),
                        Color(hex: 0xF8FBFF, alpha: 0.15),
                        Color(hex: 0xD8F0EA, alpha: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .overlay {
                LinearGradient(
                    colors: [
                        Color(hex: 0xBFCBFF, alpha: 0.18),
                        Color.white.opacity(0.04),
                        Color(hex: 0x8DDDCB, alpha: 0.12)
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
            }
            .ignoresSafeArea()
    }
}

struct CalyxLogoMark: View {
    var size: CGFloat

    var body: some View {
        if let image = calyxIconImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text("C")
                .font(.system(size: size * 0.64, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.blue)
                .frame(width: size, height: size)
        }
    }

    private var calyxIconImage: NSImage? {
        if let named = NSImage(named: "CalyxIcon") {
            return named
        }
        guard let url = Bundle.main.url(forResource: "CalyxIcon", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

enum ContainerEffectState {
    case healthy
    case starting
    case error

    init(status: ContainerStatus, isBusy: Bool) {
        if isBusy {
            self = .starting
            return
        }

        switch status {
        case .running:
            self = .healthy
        case .created, .paused:
            self = .starting
        case .exited, .stopped, .unknown:
            self = .error
        }
    }

    var tint: Color {
        switch self {
        case .healthy: Color(hex: 0x58E19A)
        case .starting: AppTheme.blue
        case .error: AppTheme.red
        }
    }

    var label: String {
        switch self {
        case .healthy: "Container healthy"
        case .starting: "Container starting"
        case .error: "Container needs attention"
        }
    }

    var systemIcon: String {
        switch self {
        case .healthy: "shippingbox.fill"
        case .starting: "arrow.triangle.2.circlepath.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }
}

struct ContainerEffectIcon: View {
    var status: ContainerStatus
    var isBusy: Bool
    var size: CGFloat

    private var effectState: ContainerEffectState {
        ContainerEffectState(status: status, isBusy: isBusy)
    }

    var body: some View {
        Image(systemName: effectState.systemIcon)
            .font(.system(size: size * 0.74, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(effectState.tint)
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .help(effectState.label)
            .accessibilityLabel(effectState.label)
    }
}

private struct ParticleCAnimationView: NSViewRepresentable {
    var state: ContainerEffectState
    var side: CGFloat
    var reduceMotion: Bool

    func makeNSView(context: Context) -> ParticleCIconView {
        ParticleCIconView(frame: NSRect(x: 0, y: 0, width: side, height: side))
    }

    func updateNSView(_ view: ParticleCIconView, context: Context) {
        view.configure(state: state, side: side, reduceMotion: reduceMotion)
    }
}

private final class ParticleCIconView: NSView {
    private var renderedKey: String?
    private var currentState: ContainerEffectState?
    private var currentSide: CGFloat = 0
    private var currentReduceMotion = false

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = false
        layer?.isGeometryFlipped = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(state: ContainerEffectState, side: CGFloat, reduceMotion: Bool) {
        currentState = state
        currentSide = side
        currentReduceMotion = reduceMotion

        if frame.size != NSSize(width: side, height: side) {
            setFrameSize(NSSize(width: side, height: side))
        }

        rebuildIfNeeded()
    }

    override func layout() {
        super.layout()
        rebuildIfNeeded()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        renderedKey = nil
        rebuildIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        renderedKey = nil
        rebuildIfNeeded()
    }

    private func rebuildIfNeeded() {
        guard let state = currentState, let rootLayer = layer, currentSide > 0 else {
            return
        }

        let scale = max(window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2, 1)
        let side = pixelAligned(min(bounds.width, bounds.height, currentSide), scale: scale)
        let key = "\(state.renderKey)-\(String(format: "%.2f", side))-\(String(format: "%.2f", scale))-\(currentReduceMotion)"
        guard renderedKey != key else {
            return
        }
        renderedKey = key

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        rootLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        rootLayer.frame = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        rootLayer.bounds = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        rootLayer.contentsScale = scale
        rootLayer.masksToBounds = false
        rootLayer.isGeometryFlipped = true
        rootLayer.opacity = 0.98

        let backingLayer = CAShapeLayer()
        backingLayer.contentsScale = scale
        backingLayer.frame = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        backingLayer.path = makeBackingPath(side: side)
        backingLayer.fillRule = .evenOdd
        backingLayer.fillColor = state.backingColor.cgColor
        backingLayer.opacity = Float(state.backingOpacity)
        backingLayer.actions = [
            "bounds": NSNull(),
            "path": NSNull(),
            "position": NSNull(),
            "opacity": NSNull()
        ]
        rootLayer.addSublayer(backingLayer)

        let points = ParticleCPoint.points(for: side)
        let mediaTime = CACurrentMediaTime()

        for (index, point) in points.enumerated() {
            let diameter = particleDiameter(for: point, side: side, scale: scale)
            let dotLayer = CALayer()
            let dotBounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            let center = CGPoint(
                x: pixelAligned(side * point.x, scale: scale),
                y: pixelAligned(side * point.y, scale: scale)
            )

            dotLayer.contentsScale = scale
            dotLayer.bounds = dotBounds
            dotLayer.position = center
            dotLayer.opacity = Float(state.restingOpacity(point: point, index: index))
            dotLayer.actions = [
                "bounds": NSNull(),
                "position": NSNull(),
                "opacity": NSNull(),
                "transform": NSNull()
            ]

            let outerDot = CAShapeLayer()
            outerDot.contentsScale = scale
            outerDot.frame = dotBounds
            outerDot.path = CGPath(ellipseIn: dotBounds, transform: nil)
            outerDot.fillColor = state.particleColor(point: point).cgColor
            outerDot.actions = ["path": NSNull(), "fillColor": NSNull()]
            dotLayer.addSublayer(outerDot)

            let coreDiameter = pixelAligned(diameter * 0.34, scale: scale)
            let coreInset = pixelAligned((diameter - coreDiameter) / 2, scale: scale)
            let coreRect = CGRect(x: coreInset, y: coreInset, width: coreDiameter, height: coreDiameter)
            let coreDot = CAShapeLayer()
            coreDot.contentsScale = scale
            coreDot.frame = dotBounds
            coreDot.path = CGPath(ellipseIn: coreRect, transform: nil)
            coreDot.fillColor = state.coreColor(point: point).cgColor
            coreDot.opacity = point.role == .body ? 0.42 : 0.34
            coreDot.actions = ["path": NSNull(), "fillColor": NSNull(), "opacity": NSNull()]
            dotLayer.addSublayer(coreDot)

            rootLayer.addSublayer(dotLayer)

            if !currentReduceMotion {
                addPulseAnimations(
                    to: dotLayer,
                    state: state,
                    point: point,
                    index: index,
                    mediaTime: mediaTime
                )
            }
        }

        CATransaction.commit()
    }

    private func particleDiameter(for point: ParticleCPoint, side: CGFloat, scale: CGFloat) -> CGFloat {
        let base = max(2.1, side * (point.role == .energy ? 0.092 : 0.078))
        return pixelAligned(base * point.weight, scale: scale)
    }

    private func addPulseAnimations(
        to layer: CALayer,
        state: ContainerEffectState,
        point: ParticleCPoint,
        index: Int,
        mediaTime: CFTimeInterval
    ) {
        let duration = state.pulseDuration
        let beginTime = mediaTime + state.phaseDelay(point: point, index: index)
        let opacityValues = state.opacityValues(point: point)
        let scaleValues = state.scaleValues(point: point)

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = opacityValues.map { NSNumber(value: $0) }
        opacity.keyTimes = [0, 0.45, 1]
        opacity.duration = duration
        opacity.beginTime = beginTime
        opacity.repeatCount = .infinity
        opacity.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = scaleValues.map { NSNumber(value: $0) }
        scale.keyTimes = [0, 0.45, 1]
        scale.duration = duration
        scale.beginTime = beginTime
        scale.repeatCount = .infinity
        scale.timingFunctions = opacity.timingFunctions

        layer.add(opacity, forKey: "calyx.particle.opacity")
        layer.add(scale, forKey: "calyx.particle.scale")
    }

    private func makeBackingPath(side: CGFloat) -> CGPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: side * x, y: side * y)
        }

        let path = CGMutablePath()
        path.move(to: point(0.74, 0.11))
        path.addCurve(to: point(0.92, 0.31), control1: point(0.83, 0.13), control2: point(0.89, 0.20))
        path.addCurve(to: point(0.83, 0.43), control1: point(0.95, 0.38), control2: point(0.91, 0.43))
        path.addLine(to: point(0.68, 0.42))
        path.addCurve(to: point(0.48, 0.31), control1: point(0.64, 0.35), control2: point(0.56, 0.31))
        path.addCurve(to: point(0.28, 0.49), control1: point(0.35, 0.31), control2: point(0.28, 0.38))
        path.addCurve(to: point(0.49, 0.69), control1: point(0.28, 0.61), control2: point(0.36, 0.69))
        path.addCurve(to: point(0.70, 0.59), control1: point(0.59, 0.69), control2: point(0.66, 0.65))
        path.addLine(to: point(0.91, 0.59))
        path.addCurve(to: point(0.83, 0.82), control1: point(0.91, 0.70), control2: point(0.89, 0.77))
        path.addCurve(to: point(0.53, 0.91), control1: point(0.74, 0.89), control2: point(0.65, 0.91))
        path.addCurve(to: point(0.16, 0.78), control1: point(0.35, 0.91), control2: point(0.23, 0.86))
        path.addCurve(to: point(0.07, 0.50), control1: point(0.09, 0.70), control2: point(0.07, 0.61))
        path.addCurve(to: point(0.17, 0.22), control1: point(0.07, 0.38), control2: point(0.10, 0.29))
        path.addCurve(to: point(0.52, 0.09), control1: point(0.25, 0.14), control2: point(0.36, 0.09))
        path.addCurve(to: point(0.74, 0.11), control1: point(0.60, 0.09), control2: point(0.67, 0.09))
        path.closeSubpath()

        path.addEllipse(in: CGRect(x: side * 0.36, y: side * 0.33, width: side * 0.28, height: side * 0.34))
        return path
    }

    private func pixelAligned(_ value: CGFloat, scale: CGFloat) -> CGFloat {
        (value * scale).rounded(.toNearestOrAwayFromZero) / scale
    }
}

private enum ParticleCRole {
    case body
    case energy
}

private struct ParticleCPoint: Identifiable {
    var id: Int
    var x: CGFloat
    var y: CGFloat
    var phase: Double
    var role: ParticleCRole
    var weight: CGFloat

    static let points: [ParticleCPoint] = {
        makeSparsePoints([
            (0.47, 0.16, 0.00, .body, 1.00), (0.57, 0.16, 0.10, .body, 1.00), (0.67, 0.16, 0.20, .body, 1.00), (0.77, 0.17, 0.30, .body, 1.00),
            (0.36, 0.22, 0.16, .body, 1.00), (0.47, 0.23, 0.26, .body, 1.00), (0.58, 0.23, 0.36, .body, 1.00), (0.70, 0.23, 0.46, .body, 1.00), (0.83, 0.26, 0.56, .body, 1.00),
            (0.27, 0.31, 0.30, .body, 1.00), (0.39, 0.32, 0.40, .body, 1.00), (0.52, 0.31, 0.50, .body, 1.00), (0.75, 0.34, 0.60, .body, 1.00), (0.89, 0.36, 0.70, .body, 1.00),
            (0.20, 0.43, 0.44, .body, 1.00), (0.32, 0.43, 0.54, .body, 1.00), (0.20, 0.55, 0.64, .body, 1.00), (0.32, 0.56, 0.74, .body, 1.00),
            (0.26, 0.68, 0.84, .body, 1.00), (0.39, 0.70, 0.94, .body, 1.00), (0.53, 0.72, 1.04, .body, 1.00), (0.65, 0.72, 1.14, .body, 1.00),
            (0.36, 0.80, 1.24, .body, 1.00), (0.48, 0.84, 1.34, .body, 1.00), (0.60, 0.84, 1.44, .body, 1.00), (0.72, 0.83, 1.54, .body, 1.00),
            (0.74, 0.66, 0.00, .energy, 1.10), (0.84, 0.65, 0.12, .energy, 1.20),
            (0.66, 0.75, 0.24, .energy, 1.08), (0.77, 0.75, 0.36, .energy, 1.22), (0.87, 0.75, 0.48, .energy, 1.10),
            (0.70, 0.85, 0.60, .energy, 1.16), (0.82, 0.85, 0.72, .energy, 1.24)
        ])
    }()

    static let compactPoints: [ParticleCPoint] = {
        makeSparsePoints([
            (0.45, 0.17, 0.00, .body, 1.02), (0.57, 0.17, 0.12, .body, 1.02), (0.70, 0.18, 0.24, .body, 1.02),
            (0.33, 0.24, 0.18, .body, 1.02), (0.48, 0.25, 0.30, .body, 1.02), (0.64, 0.25, 0.42, .body, 1.02), (0.82, 0.29, 0.54, .body, 1.02),
            (0.24, 0.36, 0.36, .body, 1.02), (0.35, 0.42, 0.48, .body, 1.02), (0.22, 0.53, 0.60, .body, 1.02), (0.33, 0.61, 0.72, .body, 1.02),
            (0.27, 0.70, 0.84, .body, 1.02), (0.42, 0.77, 0.96, .body, 1.02), (0.58, 0.81, 1.08, .body, 1.02), (0.73, 0.80, 1.20, .body, 1.02),
            (0.75, 0.67, 0.00, .energy, 1.16), (0.87, 0.68, 0.16, .energy, 1.24),
            (0.68, 0.78, 0.32, .energy, 1.14), (0.80, 0.78, 0.48, .energy, 1.26), (0.88, 0.82, 0.64, .energy, 1.14)
        ])
    }()

    static let tinyPoints: [ParticleCPoint] = {
        compactPoints
    }()

    static func points(for side: CGFloat) -> [ParticleCPoint] {
        if side <= 27 {
            compactPoints
        } else {
            points
        }
    }

    private static func makeSparsePoints(_ points: [(CGFloat, CGFloat, Double, ParticleCRole, CGFloat)]) -> [ParticleCPoint] {
        points.enumerated().map { index, point in
            ParticleCPoint(
                id: index,
                x: point.0,
                y: point.1,
                phase: point.2,
                role: point.3,
                weight: point.4
            )
        }
    }
}

private extension ContainerEffectState {
    var renderKey: String {
        switch self {
        case .healthy: "healthy"
        case .starting: "starting"
        case .error: "error"
        }
    }

    var pulseDuration: CFTimeInterval {
        switch self {
        case .healthy: 2.2
        case .starting: 1.05
        case .error: 1.25
        }
    }

    func restingOpacity(point: ParticleCPoint, index: Int) -> CGFloat {
        switch self {
        case .healthy:
            return point.role == .energy ? 0.86 : 0.74
        case .starting:
            return point.role == .energy ? 0.88 : 0.72
        case .error:
            return point.role == .energy ? 0.88 : 0.70
        }
    }

    func opacityValues(point: ParticleCPoint) -> [Double] {
        switch self {
        case .healthy:
            return point.role == .energy ? [0.64, 1.0, 0.74] : [0.64, 0.92, 0.72]
        case .starting:
            return point.role == .energy ? [0.24, 1.0, 0.42] : [0.52, 0.90, 0.62]
        case .error:
            return point.role == .energy ? [0.28, 1.0, 0.44] : [0.50, 0.86, 0.60]
        }
    }

    func scaleValues(point: ParticleCPoint) -> [Double] {
        switch self {
        case .healthy:
            return point.role == .energy ? [0.92, 1.12, 0.98] : [0.96, 1.06, 1.0]
        case .starting:
            return point.role == .energy ? [0.82, 1.22, 0.90] : [0.92, 1.10, 0.98]
        case .error:
            return point.role == .energy ? [0.84, 1.18, 0.90] : [0.92, 1.08, 0.98]
        }
    }

    func phaseDelay(point: ParticleCPoint, index: Int) -> CFTimeInterval {
        let wave = point.role == .energy ? 0.12 : 0.04
        return point.phase * 0.08 + Double(index % 4) * wave
    }

    func particleColor(point: ParticleCPoint) -> NSColor {
        switch self {
        case .healthy:
            return point.role == .energy ? NSColor(hex: 0x72E0AA) : NSColor(hex: 0x52C890)
        case .starting:
            return point.role == .energy ? NSColor(hex: 0x5CE8ED) : NSColor(hex: 0x2F75E9)
        case .error:
            return point.role == .energy ? NSColor(hex: 0xFF9B52) : NSColor(hex: 0xBF4E5D)
        }
    }

    var backingColor: NSColor {
        switch self {
        case .healthy:
            return NSColor(hex: 0x1E5F54)
        case .starting:
            return NSColor(hex: 0x183D72)
        case .error:
            return NSColor(hex: 0x693343)
        }
    }

    var backingOpacity: CGFloat {
        switch self {
        case .healthy: 0.28
        case .starting: 0.26
        case .error: 0.25
        }
    }

    func coreColor(point: ParticleCPoint) -> NSColor {
        switch self {
        case .healthy:
            return NSColor(hex: point.role == .energy ? 0x237A67 : 0x1F5F53)
        case .starting:
            return NSColor(hex: point.role == .energy ? 0x156B8B : 0x163B72)
        case .error:
            return NSColor(hex: point.role == .energy ? 0x8E523A : 0x67303E)
        }
    }
}

private extension NSColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 10
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.panelStroke, lineWidth: 1)
            }
            .shadow(color: Color(hex: 0x5F77A8, alpha: 0.08), radius: 18, x: 0, y: 10)
    }
}

struct CoreGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 10
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.coreGlassRaised.opacity(0.72),
                                AppTheme.coreGlass.opacity(0.62)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.coreStroke, lineWidth: 1)
            }
            .shadow(color: Color(hex: 0x0A1730, alpha: 0.18), radius: 22, x: 0, y: 12)
    }
}

struct StatusBadge: View {
    var status: ContainerStatus

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(status.badgeForeground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.badgeBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
            }
    }
}

struct IconButton: View {
    var systemName: String
    var title: String
    var tint: Color = AppTheme.ink
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(disabled ? AppTheme.muted.opacity(0.50) : tint)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(disabled ? 0.10 : 0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(disabled ? AppTheme.panelStroke.opacity(0.55) : AppTheme.panelStroke, lineWidth: 1)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.70 : 1)
        .help(title)
    }
}

struct ActionButton: View {
    var title: String
    var icon: String
    var tint: Color = AppTheme.blue
    var filled: Bool = false
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(disabled ? AppTheme.muted.opacity(0.55) : tint)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(filled ? tint.opacity(0.10) : Color.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(filled ? tint.opacity(0.14) : AppTheme.panelStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.72 : 1)
    }
}

struct SearchField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.muted)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 15)
        .frame(height: 40)
        .background(Color.white.opacity(0.21), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.panelStroke, lineWidth: 1)
        }
    }
}

struct SectionTitle: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(AppTheme.ink)
    }
}

struct Sparkline: View {
    var values: [Double]
    var color: Color

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(values.max() ?? 1, 1)
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = proxy.size.height - proxy.size.height * CGFloat(value / maxValue)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
    }
}

struct RuntimeIssueBanner: View {
    var issue: RuntimeIssue

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(hex: 0xFFD166))
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.ink)
                Text(issue.message)
                    .lineLimit(1)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Text(issue.recovery)
                .lineLimit(1)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.blue)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color(hex: 0xFFF1C7, alpha: 0.22), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xFFD166, alpha: 0.24), lineWidth: 1)
        }
    }
}
