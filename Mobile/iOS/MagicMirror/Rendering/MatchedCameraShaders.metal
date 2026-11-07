#include <metal_stdlib>
using namespace metal;

struct CameraRaster {
    float4 position [[position]];
    float2 normalizedViewportCoordinate;
};

vertex CameraRaster matchedCameraVertex(uint id [[vertex_id]]) {
    const float2 positions[6] = {
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1), float2(1, -1), float2(1, 1)
    };
    float2 xy = positions[id % 6];
    CameraRaster out;
    out.position = float4(xy, 0.999, 1);
    // Camera image texture and MediaPipe landmarks are top-left origin.
    out.normalizedViewportCoordinate = float2(
        (xy.x + 1) * 0.5, (1 - xy.y) * 0.5
    );
    return out;
}

fragment half4 matchedCameraFragment(
    CameraRaster in [[stage_in]],
    texture2d<half> capturedImage [[texture(0)]],
    constant float4 &bounds [[buffer(0)]]
) {
    constexpr sampler sample2D(coord::normalized,
                                address::clamp_to_edge,
                                filter::linear);
    float2 uv = mix(bounds.xy, bounds.zw,
                    in.normalizedViewportCoordinate);
    half4 sample = capturedImage.sample(sample2D, uv);
    // Opaque tracked image means the matching avatar must be composited
    // in this SAME drawable. When tracking is absent, the entire Metal
    // layer is transparent and AVFoundation's live preview shows below.
    return half4(sample.rgb, half(1.0));
}
