import AVFoundation
import Foundation
import MediaPipeTasksVision
import UIKit

enum MirrorPhase: Equatable {
    case idle
    case permissionRequested
    case searching
    case tracking
    case partialTracking
    case permissionDenied
    case unavailable(String)
}

/// Owns the ONLY phone camera, its AVFoundation BGRA frames, and the
/// on-device MediaPipe LIVE_STREAM task. No Python, Unity, TCP or cloud.
/// Never moves sample buffers to the main actor.
final class CameraPosePipeline: NSObject {
    let session = AVCaptureSession()

    // A single callback carries the matching image + pose together.
    var onAlignedFrame: ((AlignedPoseVideoFrame?) -> Void)?
    var onPhase: ((MirrorPhase) -> Void)?

    private let sessionQueue = DispatchQueue(
        label: "dev.kevoyuan.magicmirror.camera.session", qos: .userInitiated
    )
    private let framesQueue = DispatchQueue(
        label: "dev.kevoyuan.magicmirror.camera.frames", qos: .userInitiated
    )
    private let frameGate = PoseFrameAssociationGate()
    private let sourceImages = BoundedVideoFrameStore()

    private var landmarker: PoseLandmarker?
    private var configured = false
    private var wantsRunning = false
    private var notificationObservers: [NSObjectProtocol] = []

    override init() {
        super.init()
        let center = NotificationCenter.default
        let interrupted = Notification.Name(
            "AVCaptureSessionWasInterruptedNotification"
        )
        let recovered = Notification.Name(
            "AVCaptureSessionInterruptionEndedNotification"
        )
        let failure = Notification.Name(
            "AVCaptureSessionRuntimeErrorNotification"
        )
        notificationObservers.append(center.addObserver(
            forName: interrupted, object: session, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.sessionQueue.async {
                self.frameGate.reset(active: false)
                self.sourceImages.reset(active: false)
                self.postAlignedFrame(nil)
                if self.wantsRunning {
                    self.postPhase(.unavailable(
                        "Camera temporarily interrupted. Waiting to reconnect."
                    ))
                }
            }
        })
        notificationObservers.append(center.addObserver(
            forName: recovered, object: session, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.sessionQueue.async {
                guard self.wantsRunning else { return }
                self.startAuthorized()
            }
        })
        notificationObservers.append(center.addObserver(
            forName: failure, object: session, queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            let error = notification.userInfo?[
                AVCaptureSessionErrorKey
            ] as? AVError
            let canRecover = error?.code == .mediaServicesWereReset
            self.sessionQueue.async {
                self.frameGate.reset(active: false)
                self.sourceImages.reset(active: false)
                self.postAlignedFrame(nil)
                guard self.wantsRunning else { return }
                if canRecover {
                    self.startAuthorized()
                } else {
                    self.postPhase(.unavailable(
                        "Camera unavailable. Reopen MagicMirror to retry."
                    ))
                }
            }
        })
    }

    deinit {
        let center = NotificationCenter.default
        for token in notificationObservers {
            center.removeObserver(token)
        }
    }

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
            self.frameGate.reset(active: false)
            self.sourceImages.reset(active: false)
            if self.session.isRunning { self.session.stopRunning() }
            self.postAlignedFrame(nil)
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
            frameGate.reset(active: true)
            sourceImages.reset(active: true)
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
        // One same-frame foreground confidence mask for 2D silhouette
        // constrained rendering; it is NOT a depth or anatomical mask.
        options.shouldOutputSegmentationMasks = true
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
        if connection.isCameraIntrinsicMatrixDeliverySupported {
            connection.isCameraIntrinsicMatrixDeliveryEnabled = true
        }
    }

    private func postPhase(_ phase: MirrorPhase) {
        DispatchQueue.main.async { [weak self] in
            self?.onPhase?(phase)
        }
    }

    private func postAlignedFrame(_ frame: AlignedPoseVideoFrame?) {
        DispatchQueue.main.async { [weak self] in
            self?.onAlignedFrame?(frame)
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
        // Sample callback receipt uses the same monotonic clock later read
        // at Metal queue submission, unlike the media PTS timescale.
        let callbackUptime = ProcessInfo.processInfo.systemUptime
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let seconds = CMTimeGetSeconds(timestamp)
        guard seconds.isFinite, seconds >= 0 else { return }
        let timeMs = Int((seconds * 1000).rounded(.down))

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let size = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )

        let intrinsic = CameraIntrinsicMatrixReader.read(
            from: sampleBuffer, imageSize: size
        )
        guard frameGate.register(
            timestampMilliseconds: timeMs, imageSize: size,
            intrinsics: intrinsic, captureCallbackUptime: callbackUptime
        ), let landmarker,
              sourceImages.retain(
                timestampMilliseconds: timeMs,
                pixelBuffer: pixelBuffer
              ) else { return }

        do {
            let image = try MPImage(
                sampleBuffer: sampleBuffer, orientation: .up
            )
            try landmarker.detectAsync(
                image: image, timestampInMilliseconds: timeMs
            )
        } catch {
            postPhase(.unavailable("Pose inference error: \(error.localizedDescription)"))
            postAlignedFrame(nil)
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
        // Only accept a callback that matches a submitted source frame in
        // THIS capture session. A late callback from before stop/restart,
        // an out-of-order result or a >160ms-old result cannot be shown.
        guard let metadata = frameGate.consumeMetadata(
            timestampMilliseconds: timestamp
        ), let sourceImage = sourceImages.take(
            timestampMilliseconds: timestamp
        ) else { return }
        guard metadata.imageSize.width
                == CGFloat(CVPixelBufferGetWidth(sourceImage)),
              metadata.imageSize.height
                == CGFloat(CVPixelBufferGetHeight(sourceImage)) else {
            return
        }

        if let error {
            postPhase(.unavailable("Pose inference error: \(error.localizedDescription)"))
            postAlignedFrame(nil)
            return
        }
        guard let pose = result?.landmarks.first, pose.count == 33 else {
            postAlignedFrame(nil)
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
        let worldPoints: [PoseWorldPoint] = {
            guard let tracked = result?.worldLandmarks.first,
                  tracked.count == 33 else { return [] }
            return tracked.map { world in
                PoseWorldPoint(
                    x: world.x, y: world.y, z: world.z,
                    visibility: min(
                        world.visibility?.floatValue ?? 1,
                        world.presence?.floatValue ?? 1
                    )
                )
            }
        }()
        let snapshot = PoseSnapshot(
            timestampMilliseconds: timestamp,
            imageSize: metadata.imageSize,
            points: points,
            worldPoints: worldPoints,
            cameraIntrinsics: metadata.intrinsics
        )
        let silhouette = result?.segmentationMasks.first.flatMap {
            PoseSilhouetteMask.copy(from: $0)
        }
        postAlignedFrame(snapshot.isUsable
            ? AlignedPoseVideoFrame(
                pose: snapshot, pixelBuffer: sourceImage,
                silhouette: silhouette,
                captureCallbackUptime: metadata.captureCallbackUptime
            )
            : nil)
        switch snapshot.coverage {
        case .torsoAnchored: postPhase(.tracking)
        case .partial: postPhase(.partialTracking)
        case .none: postPhase(.searching)
        }
    }
}
