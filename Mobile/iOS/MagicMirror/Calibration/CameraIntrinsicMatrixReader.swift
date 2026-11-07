import AVFoundation
import CoreMedia
import Foundation
import simd

/// Reads optional camera calibration from the SAME video sample buffer
/// supplied to on-device MediaPipe. The attachment is not guaranteed on
/// every phone/capture format; never synthesize fake intrinsics if absent.
///
/// Apple's camera matrix is column-major: [fx,0,0],[0,fy,0],[cx,cy,1].
/// Depending on the attachment storage, 3x3 Float entries may be packed
/// (36 bytes) or use SIMD padded column vectors (48 bytes).
enum CameraIntrinsicMatrixReader {
    static func read(
        from sampleBuffer: CMSampleBuffer,
        imageSize: CGSize
    ) -> BodyCameraIntrinsics? {
        guard let data = CMGetAttachment(
            sampleBuffer,
            key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
            attachmentModeOut: nil
        ) as? Data else { return nil }
        return parse(data, imageSize: imageSize)
    }

    /// Pure decoding helper for synthetic fixtures and CI compilation.
    static func parse(
        _ data: Data,
        imageSize: CGSize
    ) -> BodyCameraIntrinsics? {
        let components: (Float, Float, Float, Float)
        if data.count == MemoryLayout<simd_float3x3>.size {
            let matrix = data.withUnsafeBytes {
                $0.loadUnaligned(as: simd_float3x3.self)
            }
            components = (
                matrix.columns.0.x,
                matrix.columns.1.y,
                matrix.columns.2.x,
                matrix.columns.2.y
            )
        } else if data.count == 9 * MemoryLayout<Float>.size {
            let values = data.withUnsafeBytes { raw -> [Float] in
                (0..<9).map {
                    raw.loadUnaligned(
                        fromByteOffset: $0 * MemoryLayout<Float>.size,
                        as: Float.self
                    )
                }
            }
            components = (values[0], values[4], values[6], values[7])
        } else { return nil }

        let intrinsics = BodyCameraIntrinsics(
            fx: components.0,
            fy: components.1,
            cx: components.2,
            cy: components.3,
            width: Float(imageSize.width),
            height: Float(imageSize.height)
        )
        return intrinsics.matches(image: imageSize) ? intrinsics : nil
    }
}
