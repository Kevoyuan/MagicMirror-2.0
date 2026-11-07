#include <metal_stdlib>
using namespace metal;

// Must match BoneMeshVertex in VolumetricBoneMesh.swift:
// position(float4), normal(float4), color(float4); 48-byte stride.
struct BoneVertex {
    float4 position;
    float4 normal;
    float4 color;
};

struct SkeletonRaster {
    float4 position [[position]];
    float3 normal;
    float4 color;
};

vertex SkeletonRaster boneVertex(
    uint id [[vertex_id]], const device BoneVertex* vertices [[buffer(0)]]
) {
    SkeletonRaster output;
    BoneVertex source = vertices[id];
    output.position = source.position;
    output.normal = normalize(source.normal.xyz);
    output.color = source.color;
    return output;
}

fragment half4 boneFragment(SkeletonRaster input [[stage_in]]) {
    const float3 light = normalize(float3(-0.34, 0.54, 0.78));
    float diffuse = max(dot(normalize(input.normal), light), 0.0);
    float rim = pow(1.0 - abs(input.normal.z), 2.0) * 0.20;
    float brightness = 0.37 + 0.52 * diffuse + rim;
    float3 color = clamp(input.color.rgb * brightness, 0.0, 1.0);
    return half4(half3(color), half(clamp(input.color.a, 0.0, 1.0)));
}

// Optional person silhouette alpha clip for the SAME captured MediaPipe
// image. The regular boneFragment above is kept as a clearly unmasked
// fallback if segmentation is absent/invalid. NO depth occlusion occurs.
fragment half4 boneMaskedFragment(
    SkeletonRaster input [[stage_in]],
    texture2d<float> personConfidence [[texture(1)]],
    constant float4 &sourceCrop [[buffer(1)]],
    constant float2 &invDrawableSize [[buffer(2)]]
) {
    constexpr sampler maskSampler(coord::normalized,
                                  address::clamp_to_edge,
                                  filter::linear);
    // [[position]] at fragment stage is in drawable pixel coordinates
    // with a top-left origin. Inverse drawable size converts to UV.
    float2 displayUV = saturate(input.position.xy * invDrawableSize);
    // VideoAspectFillCrop uses this exact source-image crop for the RGB
    // frame. No extra flip, separate clock, or different camera source.
    float2 sourceUV = mix(sourceCrop.xy, sourceCrop.zw, displayUV);
    float person = saturate(personConfidence.sample(maskSampler, sourceUV).r);
    // Smooth fade at model-silhouette boundaries, not an arbitrary hard edge.
    float keep = smoothstep(0.18, 0.58, person);

    const float3 light = normalize(float3(-0.34, 0.54, 0.78));
    float diffuse = max(dot(normalize(input.normal), light), 0.0);
    float rim = pow(1.0 - abs(input.normal.z), 2.0) * 0.20;
    float brightness = 0.37 + 0.52 * diffuse + rim;
    float3 color = clamp(input.color.rgb * brightness, 0.0, 1.0);
    return half4(half3(color),
                 half(clamp(input.color.a * keep, 0.0, 1.0)));
}
