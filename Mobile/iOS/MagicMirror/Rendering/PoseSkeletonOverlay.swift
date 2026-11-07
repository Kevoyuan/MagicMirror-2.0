import SwiftUI

/// Only this small view reads the high-frequency pose value. It does not
/// invalidate the camera preview layer or the rest of the controls.
struct PoseSkeletonOverlay: View {
    let snapshot: PoseSnapshot?
    let opacity: Double

    var body: some View {
        GeometryReader { proxy in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                guard let snapshot, snapshot.isUsable else { return }

                var path = Path()
                for edge in snapshot.drawableSegments {
                    guard let start = PoseSkeleton.pointInPreview(
                        snapshot.points[edge.from],
                        imageSize: snapshot.imageSize, viewSize: size
                    ), let end = PoseSkeleton.pointInPreview(
                        snapshot.points[edge.to],
                        imageSize: snapshot.imageSize, viewSize: size
                    ) else { continue }
                    path.move(to: start)
                    path.addLine(to: end)
                }

                // Deliberately stylized translucent *proxy* geometry.
                // Replace with a licensed, reviewed 3D skeletal atlas later.
                context.stroke(
                    path, with: .color(.cyan.opacity(0.22 * opacity)),
                    style: StrokeStyle(lineWidth: 19, lineCap: .round, lineJoin: .round)
                )
                context.stroke(
                    path, with: .color(Color(red: 0.69, green: 0.96, blue: 1).opacity(opacity)),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                )

                for point in snapshot.points where point.isUsable {
                    guard let p = PoseSkeleton.pointInPreview(
                        point, imageSize: snapshot.imageSize, viewSize: size
                    ) else { continue }
                    let dot = CGRect(x: p.x - 3.3, y: p.y - 3.3,
                                     width: 6.6, height: 6.6)
                    context.fill(
                        Path(ellipseIn: dot),
                        with: .color(.white.opacity(opacity * 0.84))
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
