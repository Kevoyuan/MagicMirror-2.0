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
    var skinnedAtlasBatches: [SkinnedAtlasDrawBatch] = []
    var calibratedAtlasBatches: [CalibratedAtlasDrawBatch] = []
    var selectedAtlasNodePath: String? = nil
    var selectedAtlasSystem: AnatomyDisplayLayer? = nil

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
            skinnedAtlasBatches: skinnedAtlasBatches,
            calibratedAtlasBatches: calibratedAtlasBatches,
            selectedAtlasNodePath: selectedAtlasNodePath,
            selectedAtlasSystem: selectedAtlasSystem
        )
        view.draw()
    }

    final class Renderer: NSObject, MTKViewDelegate {
        private var device: MTLDevice?
        private var commands: MTLCommandQueue?
        private var bonePipeline: MTLRenderPipelineState?
        private var skinnedPipeline: MTLRenderPipelineState?
        // Bound the sum of resident immutable geometry buffers rather
        // than replacing one atlas mesh when another layer is drawn.
        private var cachedSkinBuffers: [SkinnedAtlasCacheKey: MTLBuffer] = [:]
        private var cachedSkinLRU: [SkinnedAtlasCacheKey] = []
        private let skinCacheBudgetBytes = 48 * 1024 * 1024
        private var videoPipeline: MTLRenderPipelineState?
        private var textureCache: CVMetalTextureCache?
        private var whiteSilhouette: MTLTexture?

        private var alignedFrame: AlignedPoseVideoFrame?
        private var proxyPose: PoseSnapshot?
        private var opacity: Float = 0.65
        private var focus: AnatomyFocus = .full
        private var calibratedAtlasBatch: CalibratedAtlasDrawBatch?
        private var skinnedAtlasBatch: SkinnedAtlasDrawBatch?
        private var skinnedAtlasBatches: [SkinnedAtlasDrawBatch] = []
        private var calibratedAtlasBatches: [CalibratedAtlasDrawBatch] = []
        private var selectedAtlasNodePath: String?
        private var selectedAtlasSystem: AnatomyDisplayLayer?

        func prepare(device: MTLDevice?) {
            guard let device else { return }
            cachedSkinBuffers.removeAll()
            cachedSkinLRU.removeAll()
            self.device = device
            self.commands = device.makeCommandQueue()
            // A missing MediaPipe mask retains the existing proxy output;
            // the 1x1 confidence=1 texture is not a fabricated silhouette.
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r8Unorm, width: 1, height: 1,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead]
            if let white = device.makeTexture(descriptor: descriptor) {
                var value: UInt8 = 255
                white.replace(
                    region: MTLRegionMake2D(0, 0, 1, 1),
                    mipmapLevel: 0,
                    withBytes: &value, bytesPerRow: 1
                )
                whiteSilhouette = white
            }
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
            skinnedAtlasBatches: [SkinnedAtlasDrawBatch],
            calibratedAtlasBatches: [CalibratedAtlasDrawBatch],
            selectedAtlasNodePath: String?,
            selectedAtlasSystem: AnatomyDisplayLayer?
        ) {
            self.alignedFrame = alignedFrame
            self.proxyPose = proxyPose
            self.opacity = max(0, min(1, opacity))
            self.focus = focus
            self.calibratedAtlasBatch = calibratedAtlasBatch
            self.skinnedAtlasBatch = skinnedAtlasBatch
            self.skinnedAtlasBatches = skinnedAtlasBatches
            self.calibratedAtlasBatches = calibratedAtlasBatches
            self.selectedAtlasNodePath = selectedAtlasNodePath
            self.selectedAtlasSystem = selectedAtlasSystem
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

        /// A stable, immutable source rest mesh is uploaded once per
        /// approved package and Whole/Arms/Legs selection. Frame updates
        /// upload only compact bone matrices, camera and cut uniforms.
        private struct SkinnedAtlasCacheKey: Hashable {
            let identity: UUID
            let focus: AnatomyFocus
            let vertexCount: Int
        }

        private func cachedSkinnedMesh(
            _ skin: SkinnedAtlasDrawBatch,
            device: MTLDevice
        ) -> MTLBuffer? {
            let key = SkinnedAtlasCacheKey(
                identity: skin.geometryIdentity,
                focus: skin.focus,
                vertexCount: skin.vertices.count
            )
            if let cached = cachedSkinBuffers[key] {
                cachedSkinLRU.removeAll { $0 == key }
                cachedSkinLRU.append(key)
                return cached
            }
            guard let buffer = skin.vertices.withUnsafeBytes({
                raw -> MTLBuffer? in
                guard let address = raw.baseAddress,
                      raw.count > 0 else { return nil }
                return device.makeBuffer(
                    bytes: address, length: raw.count,
                    options: .storageModeShared
                )
            }) else { return nil }

            // One huge approved model may still be rendered; avoid
            // caching it if it would exceed the entire LRU budget.
            guard buffer.length <= skinCacheBudgetBytes else {
                return buffer
            }
            var used = cachedSkinBuffers.values.reduce(0) {
                $0 + $1.length
            }
            while used + buffer.length > skinCacheBudgetBytes,
                  !cachedSkinLRU.isEmpty {
                let oldest = cachedSkinLRU.removeFirst()
                if let victim = cachedSkinBuffers.removeValue(
                    forKey: oldest
                ) { used -= victim.length }
            }
            cachedSkinBuffers[key] = buffer
            cachedSkinLRU.append(key)
            return buffer
        }

        private func makeSilhouetteTexture(
            _ mask: PoseSilhouetteMask,
            device: MTLDevice
        ) -> MTLTexture? {
            let pixelFormat: MTLPixelFormat
            switch mask.storage {
            case .uint8: pixelFormat = .r8Unorm
            case .float32: pixelFormat = .r32Float
            }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: pixelFormat,
                width: mask.width, height: mask.height,
                mipmapped: false
            )
            descriptor.usage = [.shaderRead]
            guard let texture = device.makeTexture(
                descriptor: descriptor
            ) else { return nil }
            mask.pixels.withUnsafeBytes { source in
                guard let pointer = source.baseAddress else { return }
                texture.replace(
                    region: MTLRegionMake2D(
                        0, 0, mask.width, mask.height
                    ),
                    mipmapLevel: 0,
                    withBytes: pointer,
                    bytesPerRow: mask.width * mask.storage.bytesPerPixel
                )
            }
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

            // Every approved layer must match this exact analyzed source
            // camera frame. GPU skin batches share one video pass; no
            // second camera capture or independent video texture is made.
            if canDrawAnatomy, let frame = alignedFrame {
                // Frame association was verified by the single captured
                // video frame; its optional mask is copied from the SAME
                // PoseLandmarkerResult. UVs use the matched video crop.
                guard let crop = VideoAspectFillCrop.bounds(
                    source: frame.pose.imageSize,
                    viewport: view.bounds.size
                ), let maskTexture = frame.silhouette.flatMap({
                    makeSilhouetteTexture($0, device: device)
                }) ?? whiteSilhouette else {
                    encoder.endEncoding()
                    buffer.present(drawable)
                    buffer.commit()
                    return
                }
                var silhouetteBounds = crop
                var viewportSize = SIMD2<Float>(
                    Float(view.bounds.width), Float(view.bounds.height)
                )
                encoder.setFragmentTexture(maskTexture, index: 1)
                encoder.setFragmentBytes(
                    &silhouetteBounds,
                    length: MemoryLayout<SIMD4<Float>>.stride, index: 1
                )
                encoder.setFragmentBytes(
                    &viewportSize,
                    length: MemoryLayout<SIMD2<Float>>.stride, index: 2
                )
                let skins: [SkinnedAtlasDrawBatch] =
                    skinnedAtlasBatches.isEmpty
                    ? (skinnedAtlasBatch.map { [$0] } ?? [])
                    : skinnedAtlasBatches
                let rigids: [CalibratedAtlasDrawBatch] =
                    calibratedAtlasBatches.isEmpty
                    ? (calibratedAtlasBatch.map { [$0] } ?? [])
                    : calibratedAtlasBatches

                var drewReviewedAtlas = false
                if let bonePipeline {
                    // Rigid reference layers are drawn before skinned
                    // layers; both remain independently source-gated.
                    for batch in rigids {
                        guard batch.matches(
                            frame: frame.pose,
                            viewport: view.bounds.size,
                            focus: focus, opacity: batch.opacity
                        ),
                        let gpu = batch.vertices.withUnsafeBytes({
                            raw -> MTLBuffer? in
                            guard let address = raw.baseAddress else {
                                return nil
                            }
                            return device.makeBuffer(
                                bytes: address,
                                length: raw.count,
                                options: .storageModeShared
                            )
                        }) else { continue }
                        encoder.setRenderPipelineState(bonePipeline)
                        encoder.setCullMode(.none)
                        encoder.setVertexBuffer(
                            gpu, offset: 0, index: 0
                        )
                        encoder.drawPrimitives(
                            type: .triangle, vertexStart: 0,
                            vertexCount: batch.vertices.count
                        )
                        drewReviewedAtlas = true
                    }
                }

                if let skinnedPipeline {
                    for skin in skins {
                        guard skin.matches(
                            frame: frame.pose,
                            viewport: view.bounds.size,
                            focus: focus, opacity: skin.opacity
                        ),
                        let source = cachedSkinnedMesh(
                            skin, device: device
                        ),
                        let palette = skin.cameraMatrices.withUnsafeBytes({
                            raw -> MTLBuffer? in
                            guard let address = raw.baseAddress else {
                                return nil
                            }
                            return device.makeBuffer(
                                bytes: address,
                                length: raw.count,
                                options: .storageModeShared
                            )
                        }) else { continue }

                        encoder.setRenderPipelineState(skinnedPipeline)
                        encoder.setCullMode(.none)
                        encoder.setVertexBuffer(
                            source, offset: 0, index: 0
                        )
                        encoder.setVertexBuffer(
                            palette, offset: 0, index: 1
                        )
                        var camera = skin.cameraParameters
                        var crop = skin.viewportParameters
                        var screen = SIMD4<Float>(
                            Float(view.bounds.width),
                            Float(view.bounds.height),
                            skin.opacity * 0.58, 0
                        )
                        encoder.setVertexBytes(
                            &camera,
                            length: MemoryLayout<SIMD4<Float>>.stride,
                            index: 2
                        )
                        encoder.setVertexBytes(
                            &crop,
                            length: MemoryLayout<SIMD4<Float>>.stride,
                            index: 3
                        )
                        encoder.setVertexBytes(
                            &screen,
                            length: MemoryLayout<SIMD4<Float>>.stride,
                            index: 4
                        )
                        // A source mesh path is only meaningful within
                        // its independently reviewed anatomical system.
                        let selected = skin.anatomicalSystem ==
                            selectedAtlasSystem
                            ? skin.renderedParts.first {
                                $0.sourceHierarchyPath ==
                                    selectedAtlasNodePath
                              }
                            : nil
                        var range = selected.map {
                            SIMD2<UInt32>(
                                UInt32($0.vertexStart),
                                UInt32($0.vertexStart + $0.vertexCount)
                            )
                        } ?? SIMD2<UInt32>(
                            repeating: UInt32.max
                        )
                        encoder.setVertexBytes(
                            &range,
                            length: MemoryLayout<SIMD2<UInt32>>.stride,
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
                        drewReviewedAtlas = true
                    }
                }

                // Only draw the clearly labeled procedural proxy when
                // no approved frame-matched anatomy was rendered.
                if !drewReviewedAtlas, let bonePipeline {
                    let referencePose: PoseSnapshot
                    if let proxyPose,
                       proxyPose.timestampMilliseconds ==
                           frame.pose.timestampMilliseconds,
                       proxyPose.imageSize == frame.pose.imageSize,
                       proxyPose.hasTorsoAnchor {
                        referencePose = proxyPose
                    } else {
                        referencePose = frame.pose
                    }
                    let geometry = VolumetricBoneMesh.make(
                        snapshot: referencePose,
                        viewport: view.bounds.size,
                        opacity: opacity, focus: focus
                    )
                    if !geometry.isEmpty,
                       let gpu = geometry.withUnsafeBytes({
                        raw -> MTLBuffer? in
                        guard let address = raw.baseAddress else {
                            return nil
                        }
                        return device.makeBuffer(
                            bytes: address, length: raw.count,
                            options: .storageModeShared
                        )
                       }) {
                        encoder.setRenderPipelineState(bonePipeline)
                        encoder.setCullMode(.none)
                        encoder.setVertexBuffer(
                            gpu, offset: 0, index: 0
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
