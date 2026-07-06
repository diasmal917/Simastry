#include <metal_stdlib>
using namespace metal;

/// Spherical lens for the crystal ball: destinations inside the sphere sample
/// toward the center (magnification) with the pull easing off at the limb, so
/// the ball's inner layers visibly bulge and bend like glass. Used from
/// SwiftUI via `.distortionEffect(ShaderLibrary.crystalLens(...))`.
///
/// - size: the layer size in pixels (the ball is a centered circle in it)
/// - strength: 0 = flat, ~0.22 = pleasing bulge
[[ stitchable ]] float2 crystalLens(float2 position, float2 size, float strength) {
    float2 center = size * 0.5;
    float radius = min(size.x, size.y) * 0.5;
    float2 rel = position - center;
    float r = length(rel) / radius;
    if (r >= 1.0 || r <= 0.0001) {
        return position;
    }
    // sqrt(1-r²) is the sphere's height field: strongest pull at the center,
    // zero at the limb — sampling closer to the center magnifies the middle.
    float bulge = sqrt(max(0.0, 1.0 - r * r));
    float k = 1.0 - strength * bulge;
    return center + rel * k;
}
