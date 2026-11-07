import XCTest
@testable import MagicMirror

final class MirrorPresentationStateTests: XCTestCase {
    func testCameraPermissionAlwaysOverridesStalePose() {
        let state = MirrorPresentationState(
            phase: .permissionDenied,
            coverage: .torsoAnchored,
            isPaused: false
        )
        XCTAssertEqual(state, .permissionDenied)
        XCTAssertEqual(state.statusTitle, "CAMERA OFF")
        XCTAssertTrue(state.canOpenCameraSettings)
        XCTAssertNotNil(state.guidance)
    }

    func testPoseCoverageReflectsOnlyCurrentUsableSegments() {
        XCTAssertEqual(
            MirrorPresentationState(
                phase: .tracking, coverage: .none, isPaused: false
            ),
            .searching
        )
        XCTAssertEqual(
            MirrorPresentationState(
                phase: .tracking, coverage: .partial, isPaused: false
            ),
            .partial
        )
        XCTAssertNil(MirrorPresentationState(
            phase: .tracking, coverage: .partial, isPaused: false
        ).guidanceForUser, "Partial tracking must not cover the camera")

        let state = MirrorPresentationState(
            phase: .tracking, coverage: .torsoAnchored, isPaused: false
        )
        XCTAssertEqual(state, .tracking)
        XCTAssertNil(state.guidance)
    }

    func testPausePreventsAnyLiveTrackingClaim() {
        let state = MirrorPresentationState(
            phase: .tracking, coverage: .torsoAnchored, isPaused: true
        )
        XCTAssertEqual(state, .paused)
        XCTAssertEqual(state.statusTitle, "PAUSED")
        XCTAssertNotNil(state.guidance)
    }

    func testPermissionRequestAndInterruptionHaveDistinctStates() {
        XCTAssertEqual(
            MirrorPresentationState(
                phase: .permissionRequested, coverage: .none,
                isPaused: false
            ),
            .cameraAccess
        )
        let interrupted = MirrorPresentationState(
            phase: .unavailable("Session interrupted"),
            coverage: .torsoAnchored,
            isPaused: false
        )
        XCTAssertEqual(interrupted, .unavailable("Session interrupted"))
        XCTAssertEqual(interrupted.statusTitle, "INTERRUPTED")
        XCTAssertEqual(interrupted.guidance, "Session interrupted")
        XCTAssertFalse(interrupted.canOpenCameraSettings)
    }

    func testNoEmptyRecoveryMessage() {
        let state = MirrorPresentationState(
            phase: .unavailable(""), coverage: .none, isPaused: false
        )
        XCTAssertFalse((state.guidance ?? "").isEmpty)
        XCTAssertEqual(
            state.guidanceForUser,
            "Camera temporarily unavailable. Try reopening the app."
        )
    }
    func testCameraLifecycleOverridesPausedOverlay() {
        XCTAssertEqual(
            MirrorPresentationState(
                phase: .permissionDenied,
                coverage: .torsoAnchored,
                isPaused: true
            ),
            .permissionDenied
        )
        XCTAssertEqual(
            MirrorPresentationState(
                phase: .idle,
                coverage: .none,
                isPaused: true
            ),
            .preparing
        )
    }

}
