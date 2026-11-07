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
