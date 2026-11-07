import XCTest
import simd
@testable import MagicMirror

final class NativeKinematicsTests: XCTestCase {
    func testStraightTwoLinkWithEqualLengths() {
        let result = TwoBoneIK.solve(
            proximal: SIMD3<Float>(0, 0, 0),
            observedDistal: SIMD3<Float>(2, 0, 0),
            bendPole: SIMD3<Float>(0, 1, 0),
            firstLength: 1, secondLength: 1,
            minFlexionDegrees: 0, maxFlexionDegrees: 160
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.flexionDegrees, 0, accuracy: 0.01)
        XCTAssertEqual(simd_length(result!.joint - result!.proximal), 1, accuracy: 0.001)
        XCTAssertEqual(simd_length(result!.distal - result!.joint), 1, accuracy: 0.001)
        XCTAssertFalse(result!.targetWasClamped)
    }

    func testBentTwoLinkPreservesLengthsAndPoleSide() {
        let result = TwoBoneIK.solve(
            proximal: SIMD3<Float>(0, 0, 0),
            observedDistal: SIMD3<Float>(1, 0, 0),
            bendPole: SIMD3<Float>(0, 1, 0),
            firstLength: 1, secondLength: 1,
            minFlexionDegrees: 0, maxFlexionDegrees: 160
        )
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.joint.y, 0)
        XCTAssertEqual(result!.joint.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(simd_length(result!.joint), 1, accuracy: 0.001)
        XCTAssertEqual(simd_length(result!.distal - result!.joint), 1, accuracy: 0.001)
        XCTAssertEqual(result!.flexionDegrees, 120, accuracy: 0.01)
    }

    func testUnreachableTargetIsClamped() {
        let result = TwoBoneIK.solve(
            proximal: .zero,
            observedDistal: SIMD3<Float>(4, 0, 0),
            bendPole: SIMD3<Float>(0, 1, 0),
            firstLength: 1, secondLength: 1,
            minFlexionDegrees: 0, maxFlexionDegrees: 160
        )
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.targetWasClamped)
        XCTAssertEqual(result!.distal.x, 2, accuracy: 0.001)
    }

    func testInvalidPoleAndUndefinedAxisFailClosed() {
        let values: [(SIMD3<Float>, SIMD3<Float>)] = [
            (SIMD3<Float>(1, 0, 0), SIMD3<Float>(1, 0, 0)),
            (.zero, SIMD3<Float>(0, 1, 0))
        ]
        for (target, pole) in values {
            XCTAssertNil(TwoBoneIK.solve(
                proximal: .zero, observedDistal: target, bendPole: pole,
                firstLength: 1, secondLength: 1,
                minFlexionDegrees: 0, maxFlexionDegrees: 160
            ))
        }
    }

    func testIdentityAtlasCalibrationAndInverse() {
        let a = SIMD3<Float>(-0.25, 0, 0)
        let b = SIMD3<Float>(0.25, 0, 0)
        let hip = SIMD3<Float>(0, -0.5, 0)
        let registration = BodySimilarityRegistration.calibrate(
            sourceLeftShoulder: a, sourceRightShoulder: b,
            sourceMidHip: hip,
            atlasLeftShoulder: a, atlasRightShoulder: b,
            atlasMidHip: hip,
            allowedScale: 0.5...2, maximumPelvisResidual: 0.1
        )
        XCTAssertNotNil(registration)
        let value = SIMD3<Float>(0.1, -0.3, 0.08)
        let atlas = registration!.bodyToAtlas(value)
        XCTAssertNotNil(atlas)
        XCTAssertEqual(atlas!.x, value.x, accuracy: 0.0001)
        let roundtrip = registration!.atlasToBody(atlas!)
        XCTAssertEqual(roundtrip!.z, value.z, accuracy: 0.0001)
        XCTAssertEqual(registration!.pelvisResidualInShoulderWidths, 0, accuracy: 0.0001)
    }

    func testDegenerateCalibrationFailsInsteadOfInventingAxes() {
        XCTAssertNil(BodySimilarityRegistration.calibrate(
            sourceLeftShoulder: .zero,
            sourceRightShoulder: SIMD3<Float>(1, 0, 0),
            sourceMidHip: SIMD3<Float>(0.5, 0, 0),
            atlasLeftShoulder: SIMD3<Float>(-0.25, 0, 0),
            atlasRightShoulder: SIMD3<Float>(0.25, 0, 0),
            atlasMidHip: SIMD3<Float>(0, -0.5, 0),
            allowedScale: 0.01...10,
            maximumPelvisResidual: 0.1
        ))
    }
}
