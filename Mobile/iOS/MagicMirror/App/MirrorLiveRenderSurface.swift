import SwiftUI

/// High-frequency Metal frame boundary. The original AVFoundation preview
/// stays outside this View, so matched pose/mesh updates do not recompute
/// camera chrome or its UIViewRepresentable on every tracking callback.
struct MirrorLiveRenderSurface: View {
    let model: MirrorViewModel

    var body: some View {
        GeometryReader { geometry in
            MetalSkeletonOverlay(
                alignedFrame: model.isPaused ? nil : model.alignedFrame,
                proxyPose: model.isPaused ? nil : model.proxyRigPose,
                opacity: model.opacity,
                focus: model.focus,
                calibratedAtlasBatch: model.isPaused
                    ? nil : model.calibratedAtlasBatch,
                skinnedAtlasBatch: model.isPaused
                    ? nil : model.skinnedAtlasBatch,
                selectedAtlasNodePath: model.isPaused
                    ? nil : model.reviewedPartSelection?.sourceHierarchyPath
            )
            .overlay {
                AnatomyReferenceHighlight(model: model)
            }
            .onAppear {
                model.setViewportSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                model.setViewportSize(newSize)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
