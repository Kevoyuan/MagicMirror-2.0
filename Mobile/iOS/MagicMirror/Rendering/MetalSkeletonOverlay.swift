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
    /// Requires audited vertex influences and a verified camera frame.
    var skinnedAtlasBatch: SkinnedAtlasDrawBatch? = nil
    var reviewedSkinnedFrames: [ReviewedSkinnedLayerFrame] = []
    var reviewedRigidFrames: [ReviewedRigidLayerFrame] = []
    var selectedAtlasSystem: AnatomyDisplayLayer? = nil
    var selectedAtlasNodePath: String? = nil

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
            calibratedAtlasBatch: calibratedAtlasBatch,
            skinnedAtlasBatch: skinnedAtlasBatch,
            reviewedSkinnedFrames: reviewedSkinnedFrames,
            reviewedRigidFrames: reviewedRigidFrames,
            selectedAtlasSystem: selectedAtlasSystem,
            selectedAtlasNodePath: selectedAtlasNodePath
        )
        view.draw()
    }

    final class Renderer: NSObject, MTKViewDelegate {
        private var device: MTLDevice?
        private var commands: MTLCommandQueue?
        private var bonePipeline: MTLRenderPipelineState?
        private var skinnedPipeline: MTLRenderPipelineState?
        private var cachedSkinBuffers: [String: MTLBuffer] = [:]
        private var cachedSkinUsage: [String] = []
        private var videoPipeline: MTLRenderPipelineState?
        private var textureCache: CVMetalTextureCache?

        private var alignedFrame: AlignedPoseVideoFrame?
        private var proxyPose: PoseSnapshot?
        private var opacity: Float = 0.65
        private var focus: AnatomyFocus = .full
        private var calibratedAtlasBatch: CalibratedAtlasDrawBatch?
        private var skinnedAtlasBatch: SkinnedAtlasDrawBatch?
        private var reviewedSkinnedFrames: [ReviewedSkinnedLayerFrame] = []
        private var reviewedRigidFrames: [ReviewedRigidLayerFrame] = []
        private var selectedAtlasSystem: AnatomyDisplayLayer?
        private var selectedAtlasNodePath: String?

        func prepare(device: MTLDevice?) {
            guard let device else { return }
            cachedSkinBuffers.removeAll()
            cachedSkinUsage.removeAll()
            self.device = device
            self.commands = device.makeCommandQueue()
            guard let shaders = device.makeDefaultLibrary(),
                  let boneVertex = shaders.makeFunction(name: "boneVertex"),
                  let boneFragment = shaders.makeFunction(name: "boneFragment"),
                  let skinVertex = shaders.makeFunction(
                    name: "skinnedAtlasVertex"
                  ),
                  let skinnedSectionFragment = shaders.makeFunction(
                    name: "skinnedSectionFragment"
                  ),
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

            let skinDescriptor = MTLRenderPipelineDescriptor()
            skinDescriptor.vertexFunction = skinVertex
            skinDescriptor.fragmentFunction = skinnedSectionFragment
            let skinColor = skinDescriptor.colorAttachments[0]!
            skinColor.pixelFormat = .bgra8Unorm
            skinColor.isBlendingEnabled = true
            skinColor.rgbBlendOperation = .add
            skinColor.alphaBlendOperation = .add
            skinColor.sourceRGBBlendFactor = .sourceAlpha
            skinColor.destinationRGBBlendFactor = .oneMinusSourceAlpha
            skinColor.sourceAlphaBlendFactor = .one
            skinColor.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            skinnedPipeline = try? device.makeRenderPipelineState(
                descriptor: skinDescriptor
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
            calibratedAtlasBatch: CalibratedAtlasDrawBatch?,
            skinnedAtlasBatch: SkinnedAtlasDrawBatch?,
            reviewedSkinnedFrames: [ReviewedSkinnedLayerFrame],
            reviewedRigidFrames: [ReviewedRigidLayerFrame],
            selectedAtlasSystem: AnatomyDisplayLayer?,
            selectedAtlasNodePath: String?
        ) {
            self.alignedFrame = alignedFrame
            self.proxyPose = proxyPose
            self.opacity = max(0, min(1, opacity))
            self.focus = focus
            self.calibratedAtlasBatch = calibratedAtlasBatch
            self.skinnedAtlasBatch = skinnedAtlasBatch
            self.reviewedSkinnedFrames = reviewedSkinnedFrames
            self.reviewedRigidFrames = reviewedRigidFrames
            self.selectedAtlasSystem = selectedAtlasSystem
            self.selectedAtlasNodePath = selectedAtlasNodePath
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

        /// A small LRU of immutable per-layer GPU source meshes.
        /// Six audited systems may be composited in a single camera frame;
        /// evict older focus variants instead of reallocating all six
        /// immutable meshes on every video callback.
        private func cachedSkinnedMesh(
            _ skin: SkinnedAtlasDrawBatch,
            device: MTLDevice
        ) -> MTLBuffer? {
            let key = skin.geometryIdentity.uuidString + ":" +
                String(describing: skin.focus) + ":" +
                String(skin.vertices.count)
            if let buffer = cachedSkinBuffers[key] {
                cachedSkinUsage.removeAll { $0 == key }
                cachedSkinUsage.append(key)
                return buffer
            }
            guard let result = skin.vertices.withUnsafeBytes({
                raw -> MTLBuffer? in
                guard let address = raw.baseAddress,
                      raw.count > 0 else { return nil }
                return device.makeBuffer(
                    bytes: address,
                    length: raw.count,
                    options: .storageModeShared
                )
            }) else { return nil }
            while cachedSkinUsage.count >= 6 {
                let oldest = cachedSkinUsage.removeFirst()
                cachedSkinBuffers.removeValue(forKey: oldest)
            }
            cachedSkinUsage.append(key)
            cachedSkinBuffers[key] = result
            return result
        }

        @discardableResult
        private func encodeBoneGeometry(
            _ geometry: [BoneMeshVertex],
            device: MTLDevice,
            encoder: MTLRenderCommandEncoder,
            pipeline: MTLRenderPipelineState
        ) -> Bool {
            guard !geometry.isEmpty,
                  let vertices = geometry.withUnsafeBytes({
                    raw -> MTLBuffer? in
                    guard let pointer = raw.baseAddress else { return nil }
                    return device.makeBuffer(
                        bytes: pointer, length: raw.count,
                        options: .storageModeShared
                    )
                  }) else { return false }
            encoder.setRenderPipelineState(pipeline)
            encoder.setCullMode(.none)
            encoder.setVertexBuffer(vertices, offset: 0, index: 0)
            encoder.drawPrimitives(
                type: .triangle, vertexStart: 0,
                vertexCount: geometry.count
            )
            return true
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
               let frame = alignedFrame {
                var drewSkinnedAtlas = false
                let visibleSkins: [ReviewedSkinnedLayerFrame] =
                    reviewedSkinnedFrames.isEmpty
                    ? (skinnedAtlasBatch.map {
                        [ReviewedSkinnedLayerFrame(
                            layer: selectedAtlasSystem ?? .skeleton,
                            batch: $0
                        )]
                    } ?? [])
                    : reviewedSkinnedFrames
                for current in visibleSkins {
                    let skin = current.batch
                    guard skin.matches(
                        frame: frame.pose, viewport: view.bounds.size,
                        focus: focus, opacity: opacity
                    ), let skinnedPipeline,
                    let source = cachedSkinnedMesh(
                        skin, device: device
                    ),
                    let posePalette = skin.cameraMatrices.withUnsafeBytes({
                        bytes -> MTLBuffer? in
                        guard let address = bytes.baseAddress else {
                            return nil
                        }
                        return device.makeBuffer(
                            bytes: address, length: bytes.count,
                            options: .storageModeShared
                        )
                    }) else { continue }
                    encoder.setRenderPipelineState(skinnedPipeline)
                    encoder.setCullMode(.none)
                    encoder.setVertexBuffer(source, offset: 0, index: 0)
                    encoder.setVertexBuffer(posePalette, offset: 0, index: 1)
                    var camera = skin.cameraParameters
                    var crop = skin.viewportParameters
                    var screen = SIMD4<Float>(
                        Float(view.bounds.width),
                        Float(view.bounds.height),
                        skin.opacity * 0.58, 0
                    )
                    encoder.setVertexBytes(
                        &camera, length: MemoryLayout<SIMD4<Float>>.stride,
                        index: 2
                    )
                    encoder.setVertexBytes(
                        &crop, length: MemoryLayout<SIMD4<Float>>.stride,
                        index: 3
                    )
                    encoder.setVertexBytes(
                        &screen, length: MemoryLayout<SIMD4<Float>>.stride,
                        index: 4
                    )
                    let selected = current.layer == selectedAtlasSystem
                        ? skin.renderedParts.first {
                            $0.sourceHierarchyPath == selectedAtlasNodePath
                        } : nil
                    var range = selected.map {
                        SIMD2<UInt32>(
                            UInt32($0.vertexStart),
                            UInt32($0.vertexStart + $0.vertexCount)
                        )
                    } ?? SIMD2<UInt32>(repeating: UInt32.max)
                    encoder.setVertexBytes(
                        &range, length: MemoryLayout<SIMD2<UInt32>>.stride,
                        index: 5
                    )
                    var section = skin.sectionPlane
                    encoder.setFragmentBytes(
                        &section,
                        length: MemoryLayout<SIMD4<Float>>.stride,
                        index: 0
                    )
                    encoder.drawPrimitives(
                        type: .triangle, vertexStart: 0,
                        vertexCount: skin.vertices.count
                    )
                    drewSkinnedAtlas = true
                }

                // Independent rigid source layers can mix with skinned
                // ones. Only draw the procedural proxy if no verified
                // source layer has drawn any geometry.
                var drewRigidAtlas = false
                if let bonePipeline {
                    for current in reviewedRigidFrames {
                        let batch = current.batch
                        guard batch.matches(
                            frame: frame.pose, viewport: view.bounds.size,
                            focus: focus, opacity: opacity
                        ) else { continue }
                        if encodeBoneGeometry(
                            batch.vertices, device: device,
                            encoder: encoder, pipeline: bonePipeline
                        ) {
                            drewRigidAtlas = true
                        }
                    }
                    if !drewSkinnedAtlas && !drewRigidAtlas {
                        let geometry: [BoneMeshVertex]
                        if let batch = calibratedAtlasBatch,
                           batch.matches(
                            frame: frame.pose, viewport: view.bounds.size,
                            focus: focus, opacity: opacity
                           ) {
                            geometry = batch.vertices
                        } else {
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
                        _ = encodeBoneGeometry(
                            geometry, device: device, encoder: encoder,
                            pipeline: bonePipeline
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
