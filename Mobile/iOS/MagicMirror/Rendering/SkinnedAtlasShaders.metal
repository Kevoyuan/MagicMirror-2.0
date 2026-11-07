#include <metal_stdlib>
using namespace metal;

// Five SIMD4 values = 80 bytes; mirrors SkinnedAtlasVertex in Swift.
struct SkinnedAtlasVertex {
    float4 position;
    float4 normal;
    float4 color;
    uint4 joints;
    float4 weights;
};

struct SkinnedAtlasRaster {
    float4 position [[position]];
    float3 normal;
    float4 color;
    float3 cameraPosition;
};

/// Live atlas-rest -> camera-space linear blend skinning, then calibrated
/// pinhole projection and the exact source-image aspect-fill crop.
/// The CPU supplies only audited per-vertex weights and independently
/// calibrated, source-matched camera-space bone matrices.
vertex SkinnedAtlasRaster skinnedAtlasVertex(
    uint id [[vertex_id]],
    const device SkinnedAtlasVertex* mesh [[buffer(0)]],
    const device float4x4* bones [[buffer(1)]],
    constant float4& camera [[buffer(2)]],
    constant float4& crop [[buffer(3)]],
    constant float4& viewport [[buffer(4)]]
) {
    const SkinnedAtlasVertex v = mesh[id];
    float4 p = float4(0.0);
    float3 n = float3(0.0);
    const float3 restNormal = v.normal.xyz;
    for (uint i = 0; i < 4; ++i) {
        const float w = v.weights[i];
        if (w <= 0.0) { continue; }
        const float4x4 matrix = bones[v.joints[i]];
        p += w * (matrix * v.position);
        n += w * (float3x3(
            matrix[0].xyz, matrix[1].xyz, matrix[2].xyz
        ) * restNormal);
    }
    SkinnedAtlasRaster out;
    out.color = v.color;
    out.cameraPosition = p.xyz;
    out.normal = length(n) > 1e-6 ? normalize(n) : float3(0, 0, 1);

    if (!isfinite(p.z) || p.z <= 0.05) {
        // Unreviewed/back-of-camera points cannot be treated as
        // a measured interior view. Mark the fragment transparent.
        out.position = float4(2, 2, 1, 1);
        out.color.a = 0;
        return out;
    }
    const float2 sourcePixel = float2(
        camera.x * p.x / p.z + camera.z,
        camera.y * p.y / p.z + camera.w
    );
    const float2 displayPixel = sourcePixel * crop.x + crop.yz;
    const float2 normalized = displayPixel / viewport.xy;
    out.position = float4(
        normalized.x * 2.0 - 1.0,
        1.0 - normalized.y * 2.0,
        clamp((p.z - 0.05) / 19.95, 0.0, 1.0),
        1.0
    );
    return out;
}

/// Use the same boneFragment shading as rigid verified anatomy, rather
/// than creating a second material or implying measured body normals.


/// A real per-fragment 3D half-space clip of GPU-skinned reference mesh.
/// This cuts rendered SURFACES; it does not generate solid end caps or
/// reveal hidden medical voxels. Zero normal disables clipping.
fragment half4 skinnedSectionFragment(
    SkinnedAtlasRaster input [[stage_in]],
    constant float4& sectionPlane [[buffer(0)]]
) {
    if (dot(sectionPlane.xyz, sectionPlane.xyz) > 0.5 &&
        dot(sectionPlane.xyz, input.cameraPosition) +
        sectionPlane.w < 0.0) {
        discard_fragment();
    }
    const float3 light = normalize(float3(-0.34, 0.54, 0.78));
    const float3 n = normalize(input.normal);
    const float diffuse = max(dot(n, light), 0.0);
    const float rim = pow(1.0 - abs(n.z), 2.0) * 0.20;
    const float brightness = 0.37 + 0.52 * diffuse + rim;
    const float3 shaded = clamp(
        input.color.rgb * brightness, 0.0, 1.0
    );
    return half4(
        half3(shaded), half(clamp(input.color.a, 0.0, 1.0))
    );
}
