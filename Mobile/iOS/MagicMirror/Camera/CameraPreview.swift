import AVFoundation
import SwiftUI
import UIKit

/// UIKit is necessary here because SwiftUI has no AVCaptureVideoPreviewLayer
/// equivalent. The layer renders the *same AVCaptureSession* used for pose.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewSurface {
        let view = PreviewSurface()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: PreviewSurface, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

final class PreviewSurface: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("PreviewSurface must use AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Match the orientation applied to the video DATA output.
        if let connection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}
