import SwiftUI

/// The only high-frequency SwiftUI invalidation boundary. Tracking frames,
/// matched camera pixels and atlas draw batches change here without forcing
/// the static manuscript chrome and help controls to recompute each frame.
///
/// This is the existing AVFoundation camera session, not a second capture.
struct MirrorLiveRenderSurface: View {
    let model: MirrorViewModel

    var body: some View {
        ZStack {
            CameraPreview(session: model.pipeline.session)
                .ignoresSafeArea()

            GeometryReader { geometry in
                MetalSkeletonOverlay(
                    alignedFrame: model.isPaused ? nil : model.alignedFrame,
                    proxyPose: model.isPaused ? nil : model.proxyRigPose,
                    opacity: model.opacity,
                    focus: model.focus,
                    calibratedAtlasBatch: model.isPaused
                        ? nil : model.calibratedAtlasBatch
                )
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
        .ignoresSafeArea()
    }
}
