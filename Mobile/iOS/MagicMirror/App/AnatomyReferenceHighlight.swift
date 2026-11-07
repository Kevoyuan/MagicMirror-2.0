import SwiftUI

/// Noninteractive visual cue for the selected *observed* reference
/// segment; never a reconstructed bone or medical anatomical highlight.
struct AnatomyReferenceHighlight: View {
    let model: MirrorViewModel

    var body: some View {
        Canvas { context, size in
            guard let selected = model.referenceSelection,
                  let frame = model.snapshot,
                  selected.visible(in: frame),
                  let a = PoseSkeleton.pointInPreview(
                    frame.points[selected.fromLandmark],
                    imageSize: frame.imageSize, viewSize: size
                  ),
                  let b = PoseSkeleton.pointInPreview(
                    frame.points[selected.toLandmark],
                    imageSize: frame.imageSize, viewSize: size
                  ) else { return }

            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            context.stroke(
                path, with: .color(LeonardoPalette.verdigris),
                style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )
            for point in [a, b] {
                let rect = CGRect(
                    x: point.x - 5, y: point.y - 5,
                    width: 10, height: 10
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(LeonardoPalette.ivory)
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
