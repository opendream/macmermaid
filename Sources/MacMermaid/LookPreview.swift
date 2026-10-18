import SwiftUI

enum DiagramLook: String, CaseIterable, Identifiable {
    case neo, classic, handDrawn

    var id: String { rawValue }
    var title: String {
        switch self {
        case .neo: "Neo"
        case .classic: "Classic"
        case .handDrawn: "Hand-drawn"
        }
    }
    var detail: String {
        switch self {
        case .neo: "Soft corners and subtle shadows"
        case .classic: "Clean outlines and flat shapes"
        case .handDrawn: "Sketch-like outlines and connections"
        }
    }
}

/// Fixed sample illustrations keep the choices readable without rendering the user's
/// document again. They describe the drawing style, independently of its theme/layout.
struct LookPreview: View {
    let look: DiagramLook

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 100, y: size.height / 50)
            let box = boxPath
            let diamond = diamondPath
            if look == .neo {
                var shadow = context
                shadow.translateBy(x: 2, y: 2)
                shadow.fill(box, with: .color(.primary.opacity(0.12)))
                shadow.fill(diamond, with: .color(.primary.opacity(0.12)))
            }
            for shape in [box, diamond] {
                context.fill(shape, with: .color(Color(nsColor: .controlBackgroundColor)))
                context.stroke(shape, with: .color(.primary.opacity(0.8)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }
            var connection = Path()
            connection.move(to: CGPoint(x: 38, y: 25))
            if look == .handDrawn {
                connection.addCurve(to: CGPoint(x: 65, y: 25), control1: CGPoint(x: 47, y: 23.5), control2: CGPoint(x: 55, y: 27))
            } else {
                connection.addLine(to: CGPoint(x: 65, y: 25))
            }
            context.stroke(connection, with: .color(.primary.opacity(0.8)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            var arrow = Path()
            arrow.move(to: CGPoint(x: 61, y: 22))
            arrow.addLine(to: CGPoint(x: 65, y: 25))
            arrow.addLine(to: CGPoint(x: 61, y: 28))
            context.stroke(arrow, with: .color(.primary.opacity(0.8)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }

    private var boxPath: Path {
        if look != .handDrawn {
            return Path(roundedRect: CGRect(x: 3, y: 12, width: 33, height: 26), cornerRadius: look == .neo ? 5 : 0)
        }
        return Path { path in
            path.move(to: CGPoint(x: 3, y: 12.5))
            path.addCurve(to: CGPoint(x: 36, y: 12), control1: CGPoint(x: 12, y: 10.5), control2: CGPoint(x: 27, y: 13.5))
            path.addCurve(to: CGPoint(x: 35.5, y: 38), control1: CGPoint(x: 34.5, y: 21), control2: CGPoint(x: 37, y: 30))
            path.addCurve(to: CGPoint(x: 3, y: 37.5), control1: CGPoint(x: 24, y: 36.5), control2: CGPoint(x: 12, y: 39))
            path.addCurve(to: CGPoint(x: 3, y: 12.5), control1: CGPoint(x: 4.5, y: 29), control2: CGPoint(x: 1.5, y: 20))
            path.closeSubpath()
        }
    }

    private var diamondPath: Path {
        Path { path in
            if look == .neo {
                path.move(to: CGPoint(x: 79, y: 10))
                path.addQuadCurve(to: CGPoint(x: 82, y: 10), control: CGPoint(x: 80.5, y: 8.5))
                path.addLine(to: CGPoint(x: 95, y: 23.5))
                path.addQuadCurve(to: CGPoint(x: 95, y: 26.5), control: CGPoint(x: 96.5, y: 25))
                path.addLine(to: CGPoint(x: 82, y: 40))
                path.addQuadCurve(to: CGPoint(x: 79, y: 40), control: CGPoint(x: 80.5, y: 41.5))
                path.addLine(to: CGPoint(x: 66, y: 26.5))
                path.addQuadCurve(to: CGPoint(x: 66, y: 23.5), control: CGPoint(x: 64.5, y: 25))
            } else if look == .handDrawn {
                path.move(to: CGPoint(x: 80.5, y: 9))
                path.addQuadCurve(to: CGPoint(x: 96, y: 25), control: CGPoint(x: 86.5, y: 18.5))
                path.addQuadCurve(to: CGPoint(x: 80, y: 41), control: CGPoint(x: 90.5, y: 34.5))
                path.addQuadCurve(to: CGPoint(x: 65, y: 25), control: CGPoint(x: 71, y: 35))
                path.addQuadCurve(to: CGPoint(x: 80.5, y: 9), control: CGPoint(x: 74, y: 19))
            } else {
                path.move(to: CGPoint(x: 80.5, y: 9))
                path.addLine(to: CGPoint(x: 96, y: 25))
                path.addLine(to: CGPoint(x: 80.5, y: 41))
                path.addLine(to: CGPoint(x: 65, y: 25))
            }
            path.closeSubpath()
        }
    }
}
