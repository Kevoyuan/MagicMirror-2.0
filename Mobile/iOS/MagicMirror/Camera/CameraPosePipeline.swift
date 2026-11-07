import AVFoundation
import Foundation
import MediaPipeTasksVision
import UIKit

enum MirrorPhase: Equatable {
    case idle
    case permissionRequested
    case searching
    case tracking
    case permissionDenied
    case unavailable(String)
}

/// Owns the ONLY phone camera, its AVFoundation BGRA frames, and the
/// on-device MediaPipe LIVE_STREAM task. No Python, Unity, TCP or cloud.
/// Never moves sample buffers to the main actor.
final class CameraPosePipeline: NSObject {
    let session = AVCaptureSession()

    var onPose: ((PoseSnapshot?) -> Void)?
    var onPhase: ((MirrorPhase) -> Void)?

    private let sessionQueue = DispatchQueue(
        label: "dev.kevoyuan.magicmirror.camera.session", qos: .userInitiated
    )
    private let framesQueue = DispatchQueue(
        label: "dev.kevoyuan.magicmirror.camera.frames", qos: .userInitiated
    )
    private let timingLock = NSLock()

    private var landmarker: PoseLandmarker?
    private var configured = false
    private var wantsRunning = false
    private var lastSubmittedMs = -1   // framesQueue only
    private var latestCapturedMs = -1  // timingLock guarded
    private var lastPublishedMs = -1   // timingLock guarded
    private var currentImageSize = CGSize.zero
    private var acceptResults = false

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.startAuthorized()
            case .notDetermined:
                self.postPhase(.permissionRequested)
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    guard let self else { return }
                    self.sessionQueue.async {
                        guard self.wantsRunning else { return }
                        if granted {
                            self.startAuthorized()
                        } else {
                            self.postPhase(.permissionDenied)
                        }
                    }
                }
            case .denied, .restricted:
                self.postPhase(.permissionDenied)
            @unknown default:
                self.postPhase(.unavailable("Camera permission state not supported"))
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = false
            self.timingLock.lock()
            self.acceptResults = false
            self.timingLock.unlock()
            if self.session.isRunning { self.session.stopRunning() }
            self.postPose(nil)
            self.postPhase(.idle)
        }
    }

    private func startAuthorized() {
        guard wantsRunning else { return }
        do {
            if landmarker == nil {
                landmarker = try makeLandmarker()
            }
            if !configured {
                try configureCamera()
                configured = true
            }
            timingLock.lock()
            acceptResults = true
            latestCapturedMs = -1
            lastPublishedMs = -1
            timingLock.unlock()
            // AVCaptureSession.startRunning MUST NOT run on main.
            if !session.isRunning { session.startRunning() }
            postPhase(.searching)
        } catch {
            postPhase(.unavailable(error.localizedDescription))
        }
    }

    private func makeLandmarker() throws -> PoseLandmarker {
        guard let path = Bundle.main.path(
            forResource: "pose_landmarker_lite", ofType: "task"
        ) else {
            throw CameraError.missingModel
        }
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = path
        options.runningMode = .liveStream
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.5
        options.minPosePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.shouldOutputSegmentationMasks = false
        options.poseLandmarkerLiveStreamDelegate = self
        return try PoseLandmarker(options: options)
    }

    private func configureCamera() throws {
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ) else {
            throw CameraError.noRearCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                Int(kCVPixelFormatType_32BGRA)
        ]
        output.alwaysDiscardsLateVideoFrames = true

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720

        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw CameraError.invalidCaptureConfiguration
        }
        session.addInput(input)
        session.addOutput(output)
        output.setSampleBufferDelegate(self, queue: framesQueue)

        // Rotate the *actual BGRA buffers* to portrait (not just the UI);
        // MPImage orientation remains .up, matching the preview's 90°.
        guard let connection = output.connection(with: .video),
              connection.isVideoRotationAngleSupported(90) else {
            throw CameraError.unsupportedPortraitRotation
        }
        connection.videoRotationAngle = 90
        connection.isVideoMirrored = false
    }

    private func postPhase(_ phase: MirrorPhase) {
        DispatchQueue.main.async { [weak self] in
            self?.onPhase?(phase)
        }
    }

    private func postPose(_ pose: PoseSnapshot?) {
        DispatchQueue.main.async { [weak self] in
            self?.onPose?(pose)
        }
    }

    private enum CameraError: LocalizedError {
        case missingModel
        case noRearCamera
        case invalidCaptureConfiguration
        case unsupportedPortraitRotation

        var errorDescription: String? {
            switch self {
            case .missingModel:
                return "Missing verified pose_landmarker_lite.task bundle"
            case .noRearCamera:
                return "A rear-facing camera is required"
            case .invalidCaptureConfiguration:
                return "Could not configure the camera"
            case .unsupportedPortraitRotation:
                return "Device cannot provide aligned portrait camera frames"
            }
        }
    }
}

extension CameraPosePipeline: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let seconds = CMTimeGetSeconds(timestamp)
        guard seconds.isFinite, seconds >= 0 else { return }
        let timeMs = Int((seconds * 1000).rounded(.down))
        guard timeMs > lastSubmittedMs else { return }
        lastSubmittedMs = timeMs

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let size = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )

        timingLock.lock()
        let accepting = acceptResults
        if accepting {
            latestCapturedMs = timeMs
            currentImageSize = size
        }
        timingLock.unlock()
        guard accepting, let landmarker else { return }

        do {
            let image = try MPImage(
                sampleBuffer: sampleBuffer, orientation: .up
            )
            try landmarker.detectAsync(
                image: image, timestampInMilliseconds: timeMs
            )
        } catch {
            postPhase(.unavailable("Pose inference error: \(error.localizedDescription)"))
            postPose(nil)
        }
    }
}

extension CameraPosePipeline: PoseLandmarkerLiveStreamDelegate {
    func poseLandmarker(
        _ poseLandmarker: PoseLandmarker,
        didFinishDetection result: PoseLandmarkerResult?,
        timestampInMilliseconds timestamp: Int,
        error: Error?
    ) {
        timingLock.lock()
        let currentTimestamp = latestCapturedMs
        let size = currentImageSize
        let accepting = acceptResults
        let newer = timestamp > lastPublishedMs
        // Reject stale or out-of-order poses; never present an old body
        // landmark overlay as if it belongs to today's latest preview.
        let timely = currentTimestamp >= timestamp &&
                     currentTimestamp - timestamp <= 160
        if accepting && newer && timely {
            lastPublishedMs = timestamp
        }
        timingLock.unlock()
        guard accepting, newer, timely else { return }

        if let error {
            postPhase(.unavailable("Pose inference error: \(error.localizedDescription)"))
            postPose(nil)
            return
        }
        guard let pose = result?.landmarks.first, pose.count == 33 else {
            postPose(nil)
            postPhase(.searching)
            return
        }

        let points: [PosePoint] = pose.map { point in
            PosePoint(
                x: CGFloat(point.x), y: CGFloat(point.y),
                visibility: min(
                    point.visibility?.floatValue ?? 1.0,
                    point.presence?.floatValue ?? 1.0
                )
            )
        }
        let snapshot = PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: size,
            points: points
        )
        postPose(snapshot.isUsable ? snapshot : nil)
        postPhase(snapshot.isUsable ? .tracking : .searching)
    }
}
