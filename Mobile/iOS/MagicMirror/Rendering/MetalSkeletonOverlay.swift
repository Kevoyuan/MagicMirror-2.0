import CoreVideo
import Metal
import MetalKit
import SwiftUI
import UIKit

/// One Metal drawable contains BOTH the actual camera BGRA frame that
/// MediaPipe analyzed and the 3D reference geometry from its pose result.
/// There is no second camera session, cloud upload, or hidden video copy.
struct MetalSkeletonOverlay: UIViewRepresentable {
    let alignedFrame: AlignedPoseVideoFrame?
    /// Fixed-length IK reconstruction for reference display only.
    let proxyPose: PoseSnapshot?
    let opacity: Double
    let focus: AnatomyFocus
    /// Absent until a reviewed atlas and independently calibrated camera
    /// can produce a validated same-frame batch. Default UI passes nil.
    var calibratedAtlasBatch: CalibratedAtlasDrawBatch? = nil

    func makeCoordinator() -> Renderer { Renderer() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(
            red: 0, green: 0, blue: 0, alpha: 0
        )
        view.isOpaque = false
        view.layer.isOpaque = false
        view.backgroundColor = .clear
        view.framebufferOnly = true
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.preferredFramesPerSecond = 30
        view.delegate = context.coordinator
        context.coordinator.prepare(device: view.device)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.update(
            alignedFrame: alignedFrame, proxyPose: proxyPose,
            opacity: Float(opacity), focus: focus,
            calibratedAtlasBatch: calibratedAtlasBatch
        )
        view.draw()
    }

    final class Renderer: NSObject, MTKViewDelegate {
        private var device: MTLDevice?
        private var commands: MTLCommandQueue?
        private var bonePipeline: MTLRenderPipelineState?
        private var videoPipeline: MTLRenderPipelineState?
        private var textureCache: CVMetalTextureCache?

        private var alignedFrame: AlignedPoseVideoFrame?
        private var proxyPose: PoseSnapshot?
        private var opacity: Float = 0.65
        private var focus: AnatomyFocus = .full
        private var calibratedAtlasBatch: CalibratedAtlasDrawBatch?

        func prepare(device: MTLDevice?) {
            guard let device else { return }
            self.device = device
            self.commands = device.makeCommandQueue()
            guard let shaders = device.makeDefaultLibrary(),
                  let boneVertex = shaders.makeFunction(name: "boneVertex"),
                  let boneFragment = shaders.makeFunction(name: "boneFragment"),
                  let videoVertex = shaders.makeFunction(
                    name: "matchedCameraVertex"
                  ),
                  let videoFragment = shaders.makeFunction(
                    name: "matchedCameraFragment"
                  ) else { return }

            let videoDescriptor = MTLRenderPipelineDescriptor()
            videoDescriptor.vertexFunction = videoVertex
            videoDescriptor.fragmentFunction = videoFragment
            videoDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            videoPipeline = try? device.makeRenderPipelineState(
                descriptor: videoDescriptor
            )

            let boneDescriptor = MTLRenderPipelineDescriptor()
            boneDescriptor.vertexFunction = boneVertex
            boneDescriptor.fragmentFunction = boneFragment
            let color = boneDescriptor.colorAttachments[0]!
            color.pixelFormat = .bgra8Unorm
            color.isBlendingEnabled = true
            color.rgbBlendOperation = .add
            color.alphaBlendOperation = .add
            color.sourceRGBBlendFactor = .sourceAlpha
            color.destinationRGBBlendFactor = .oneMinusSourceAlpha
            color.sourceAlphaBlendFactor = .one
            color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            bonePipeline = try? device.makeRenderPipelineState(
                descriptor: boneDescriptor
            )

            var cache: CVMetalTextureCache?
            if CVMetalTextureCacheCreate(
                kCFAllocatorDefault, nil, device, nil, &cache
            ) == kCVReturnSuccess {
                textureCache = cache
            }

            // Do not auto-load an uncalibrated atlas. A future asset
            // coordinator must independently verify the mesh, coherent
            // rig, camera extrinsics and matching-frame reprojection
            // before passing an immutable CalibratedAtlasDrawBatch.
        }

        func update(
            alignedFrame: AlignedPoseVideoFrame?,
            proxyPose: PoseSnapshot?,
            opacity: Float, focus: AnatomyFocus,
            calibratedAtlasBatch: CalibratedAtlasDrawBatch?
        ) {
            self.alignedFrame = alignedFrame
            self.proxyPose = proxyPose
            self.opacity = max(0, min(1, opacity))
            self.focus = focus
            self.calibratedAtlasBatch = calibratedAtlasBatch
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            view.draw()
        }

        private func wrapBGRA(
            _ buffer: CVPixelBuffer
        ) -> CVMetalTexture? {
            guard let textureCache,
                  CVPixelBufferGetPixelFormatType(buffer)
                    == kCVPixelFormatType_32BGRA else { return nil }
            var texture: CVMetalTexture?
            let status = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache, buffer, nil,
                .bgra8Unorm,
                CVPixelBufferGetWidth(buffer),
                CVPixelBufferGetHeight(buffer),
                0, &texture
            )
            guard status == kCVReturnSuccess else { return nil }
            return texture
        }

        func draw(in view: MTKView) {
            guard let pass = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let device, let commands,
                  let buffer = commands.makeCommandBuffer(),
                  let encoder = buffer.makeRenderCommandEncoder(
                    descriptor: pass
                  ) else { return }

            var canDrawAnatomy = false
            if let frame = alignedFrame,
               frame.pose.isUsable,
               let videoPipeline,
               let bounds = VideoAspectFillCrop.bounds(
                    source: frame.pose.imageSize,
                    viewport: view.bounds.size
               ),
               frame.pose.imageSize.width
                    == CGFloat(CVPixelBufferGetWidth(frame.pixelBuffer)),
               frame.pose.imageSize.height
                    == CGFloat(CVPixelBufferGetHeight(frame.pixelBuffer)),
               let coreVideoTexture = wrapBGRA(frame.pixelBuffer),
               let imageTexture = CVMetalTextureGetTexture(coreVideoTexture) {
                encoder.setCullMode(.none)
                encoder.setRenderPipelineState(videoPipeline)
                encoder.setFragmentTexture(imageTexture, index: 0)
                var crop = bounds
                encoder.setFragmentBytes(
                    &crop, length: MemoryLayout<SIMD4<Float>>.stride,
                    index: 0
                )
                encoder.drawPrimitives(
                    type: .triangle, vertexStart: 0, vertexCount: 6
                )
                // Keep CoreVideo's pixel buffer texture wrapper alive
                // until the GPU is finished sampling it.
                buffer.addCompletedHandler { _ in
                    _ = coreVideoTexture
                }
                canDrawAnatomy = true
            }

            // When no matched source exists, clear to fully transparent.
            // The *single* AVFoundation preview keeps showing behind it.
            // Never render model-only geometry over a mismatched frame.
            if canDrawAnatomy,
               let frame = alignedFrame,
               let bonePipeline {
                let geometry: [BoneMeshVertex]
                if let batch = calibratedAtlasBatch,
                   batch.matches(
                    frame: frame.pose, viewport: view.bounds.size,
                    focus: focus, opacity: opacity
                   ) {
                    geometry = batch.vertices
                } else {
                    // Use fixed-length live IK only on its matching source
                    // camera frame. Missing/stale geometry falls back to
                    // the current confidence-gated procedural proxy.
                    let referencePose: PoseSnapshot
                    if let proxyPose,
                       proxyPose.timestampMilliseconds
                           == frame.pose.timestampMilliseconds,
                       proxyPose.imageSize == frame.pose.imageSize,
                       proxyPose.hasTorsoAnchor {
                        referencePose = proxyPose
                    } else {
                        referencePose = frame.pose
                    }
                    geometry = VolumetricBoneMesh.make(
                        snapshot: referencePose,
                        viewport: view.bounds.size,
                        opacity: opacity, focus: focus
                    )
                }

                if !geometry.isEmpty {
                    let gpuVertices = geometry.withUnsafeBytes {
                        raw -> MTLBuffer? in
                        guard let address = raw.baseAddress else { return nil }
                        return device.makeBuffer(
                            bytes: address, length: raw.count,
                            options: .storageModeShared
                        )
                    }
                    if let gpuVertices {
                        encoder.setRenderPipelineState(bonePipeline)
                        encoder.setCullMode(.none)
                        encoder.setVertexBuffer(
                            gpuVertices, offset: 0, index: 0
                        )
                        encoder.drawPrimitives(
                            type: .triangle, vertexStart: 0,
                            vertexCount: geometry.count
                        )
                    }
                }
            }

            encoder.endEncoding()
            buffer.present(drawable)
            buffer.commit()
        }
    }
}
