import Metal
import MetalKit
import SwiftUI
import UIKit

/// A translucent Metal layer *over* AVFoundation's live video, not another
/// camera owner or ARSession. The GPU draws a shaded 3D proxy mesh based on
/// current, source-time-associated MediaPipe landmarks.
struct MetalSkeletonOverlay: UIViewRepresentable {
    let snapshot: PoseSnapshot?
    let opacity: Double
    let focus: AnatomyFocus

    func makeCoordinator() -> Renderer {
        Renderer()
    }

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
            snapshot: snapshot,
            opacity: Float(opacity), focus: focus
        )
        view.draw()
    }

    /// Render state is owned by this one view and never stored in global
    /// SwiftUI state. Metal command queue and pipeline are reused.
    final class Renderer: NSObject, MTKViewDelegate {
        private var device: MTLDevice?
        private var commands: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private var snapshot: PoseSnapshot?
        private var opacity: Float = 0.65
        private var focus: AnatomyFocus = .full

        func prepare(device: MTLDevice?) {
            guard let device else { return }
            self.device = device
            self.commands = device.makeCommandQueue()

            guard let shaderLibrary = device.makeDefaultLibrary(),
                  let vertex = shaderLibrary.makeFunction(name: "boneVertex"),
                  let fragment = shaderLibrary.makeFunction(name: "boneFragment")
            else { return }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            let attachment = descriptor.colorAttachments[0]!
            attachment.pixelFormat = .bgra8Unorm
            attachment.isBlendingEnabled = true
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            self.pipeline = try? device.makeRenderPipelineState(
                descriptor: descriptor
            )
        }

        func update(
            snapshot: PoseSnapshot?, opacity: Float, focus: AnatomyFocus
        ) {
            self.snapshot = snapshot
            self.opacity = max(0, min(1, opacity))
            self.focus = focus
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            view.draw()
        }

        func draw(in view: MTKView) {
            guard let pass = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let device, let commands,
                  let commandBuffer = commands.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(
                      descriptor: pass
                  ) else { return }

            if let pipeline {
                let geometry = VolumetricBoneMesh.make(
                    snapshot: snapshot, viewport: view.bounds.size,
                    opacity: opacity, focus: focus
                )
                if !geometry.isEmpty {
                    let bytes = geometry.withUnsafeBytes { raw -> MTLBuffer? in
                        guard let base = raw.baseAddress else { return nil }
                        return device.makeBuffer(
                            bytes: base, length: raw.count,
                            options: .storageModeShared
                        )
                    }
                    if let bytes {
                        encoder.setRenderPipelineState(pipeline)
                        encoder.setCullMode(.none)
                        encoder.setVertexBuffer(bytes, offset: 0, index: 0)
                        encoder.drawPrimitives(
                            type: .triangle,
                            vertexStart: 0, vertexCount: geometry.count
                        )
                    }
                }
            }
            // Empty geometry still submits a transparent clear: no ghost
            // body remains when the subject leaves frame or user pauses.
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
