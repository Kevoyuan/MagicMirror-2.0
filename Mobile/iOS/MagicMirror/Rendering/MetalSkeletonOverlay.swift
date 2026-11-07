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
    let opacity: Double
    let focus: AnatomyFocus

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
            alignedFrame: alignedFrame,
            opacity: Float(opacity), focus: focus
        )
        view.draw()
    }

    final class Renderer: NSObject, MTKViewDelegate {
        private var device: MTLDevice?
        private var commands: MTLCommandQueue?
        private var bonePipeline: MTLRenderPipelineState?
        private var maskedBonePipeline: MTLRenderPipelineState?
        private var videoPipeline: MTLRenderPipelineState?
        private var textureCache: CVMetalTextureCache?

        private var alignedFrame: AlignedPoseVideoFrame?
        private var opacity: Float = 0.65
        private var focus: AnatomyFocus = .full
        private var approvedAtlas: VerifiedAnatomyAtlas?

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
            if let maskedFragment = shaders.makeFunction(
                name: "boneMaskedFragment"
            ) {
                boneDescriptor.fragmentFunction = maskedFragment
                maskedBonePipeline = try? device.makeRenderPipelineState(
                    descriptor: boneDescriptor
                )
            }

            var cache: CVMetalTextureCache?
            if CVMetalTextureCacheCreate(
                kCFAllocatorDefault, nil, device, nil, &cache
            ) == kCVReturnSuccess {
                textureCache = cache
            }

            // Approved atlas stays optional and still fails closed if
            // licensing, SHA, mesh identities or anchor reviews are absent.
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let atlas = try? VerifiedAnatomyAtlas.load()
                DispatchQueue.main.async { [weak self] in
                    self?.approvedAtlas = atlas
                }
            }
        }

        func update(
            alignedFrame: AlignedPoseVideoFrame?,
            opacity: Float, focus: AnatomyFocus
        ) {
            self.alignedFrame = alignedFrame
            self.opacity = max(0, min(1, opacity))
            self.focus = focus
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

        /// Create a one-channel GPU texture from data copied in the same
        /// MediaPipe callback as the source video. No image upload or
        /// persistent pixel buffer outside the current frame.
        private func makeSilhouetteTexture(
            _ silhouette: PersonSilhouetteMask,
            device: MTLDevice
        ) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Float,
                width: silhouette.width, height: silhouette.height,
                mipmapped: false
            )
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared
            guard let texture = device.makeTexture(
                descriptor: descriptor
            ) else { return nil }
            let copied = silhouette.confidence.withUnsafeBytes {
                raw -> Bool in
                guard let address = raw.baseAddress else { return false }
                texture.replace(
                    region: MTLRegionMake2D(
                        0, 0, silhouette.width, silhouette.height
                    ),
                    mipmapLevel: 0, withBytes: address,
                    bytesPerRow: silhouette.width *
                        MemoryLayout<Float>.stride
                )
                return true
            }
            return copied ? texture : nil
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
                if let approvedAtlas {
                    geometry = approvedAtlas.makeProjectedMesh(
                        snapshot: frame.pose,
                        viewport: view.bounds.size,
                        opacity: opacity, focus: focus
                    )
                } else {
                    geometry = VolumetricBoneMesh.make(
                        snapshot: frame.pose,
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
                        if let silhouette = frame.silhouette,
                           let masked = maskedBonePipeline,
                           let crop = VideoAspectFillCrop.bounds(
                                source: frame.pose.imageSize,
                                viewport: view.bounds.size
                           ),
                           view.drawableSize.width > 0,
                           view.drawableSize.height > 0,
                           let maskTexture = makeSilhouetteTexture(
                                silhouette, device: device
                           ) {
                            // UV crop is exactly the same as the RGB
                            // frame's source-to-viewport mapping.
                            encoder.setRenderPipelineState(masked)
                            encoder.setFragmentTexture(
                                maskTexture, index: 1
                            )
                            var bounds = crop
                            encoder.setFragmentBytes(
                                &bounds,
                                length: MemoryLayout<SIMD4<Float>>.stride,
                                index: 1
                            )
                            var inverseSize = SIMD2<Float>(
                                1 / Float(view.drawableSize.width),
                                1 / Float(view.drawableSize.height)
                            )
                            encoder.setFragmentBytes(
                                &inverseSize,
                                length: MemoryLayout<SIMD2<Float>>.stride,
                                index: 2
                            )
                            // Keep the just-uploaded mask texture alive
                            // until this GPU command buffer finishes.
                            buffer.addCompletedHandler { _ in
                                _ = maskTexture
                            }
                        } else {
                            // Explicit no-mask fallback: never borrow the
                            // previous person segmentation from another
                            // pose timestamp or capture session.
                            encoder.setRenderPipelineState(bonePipeline)
                        }
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
