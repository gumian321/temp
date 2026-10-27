#ifndef CAVE_SWEEP_KERNEL_H
#define CAVE_SWEEP_KERNEL_H

#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define CAVE_SWEEP_API __declspec(dllexport)
#elif defined(__GNUC__) || defined(__clang__)
#define CAVE_SWEEP_API __attribute__((visibility("default")))
#else
#define CAVE_SWEEP_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

enum { CAVE_SWEEP_EDGE_STRIDE = 13, CAVE_SWEEP_QUERY_SIZE = 9, CAVE_SWEEP_OVERLAP_QUERY_SIZE = 3 };

typedef struct CaveSweepHit {
    int64_t index;
    double time;
} CaveSweepHit;

/* Each edge: a.xy, b.xy, delta.xy, normal.xy, length_squared,
 * bounds.position.xy, bounds.size.xy (13 doubles).
 * Query: start.xy, delta.xy, radius, query_rect.position.xy,
 * query_rect.size.xy (9 doubles). The caller supplies the original edge order
 * and the exact Rect2 query produced by local_wall_hit.
 *
 * Result {-1, INFINITY} means no hit (also returned for invalid array lengths,
 * null pointers, or a nonfinite/unrepresentable query). Invalid edges are
 * skipped: nonfinite values, components outside float32 range, nonpositive
 * length_squared, or negative bounds sizes. Negative query sizes are rejected.
 * Buffers must contain the declared number of doubles and remain immutable.
 *
 * Matches standard float32 Godot Vector2/Rect2 with float64 GDScript scalars;
 * double-precision Godot builds are unsupported. Compile without fast math or
 * floating-point contraction; default rounding must be round-to-nearest.
 * This isolated C11 math API performs no allocation, callbacks, or registration.
 */
CAVE_SWEEP_API CaveSweepHit cave_sweep_scan(
    const double *edges, size_t edge_value_count,
    const double *query, size_t query_value_count);

/* Boundary-only portion of wall_blocked: query is [point.x, point.y, radius].
 * Returns the first overlapping edge index, or -1 for no overlap/invalid input.
 * Radius <= 0 has no boundary overlap, matching wall_blocked's outer guard.
 * Does not test filled rock interiors or material/clearance certificates.
 * Applies float32 bounds.grow(radius).has_point(point) with half-open borders,
 * then float32 Godot closest-point/distance and a float64 radius-squared test.
 * A degenerate segment returns its first endpoint as Godot does. Cached edge
 * length_squared may be zero here (it is not used), but must be finite and
 * nonnegative. Other input, precision and ownership rules are as above.
 */
CAVE_SWEEP_API int64_t cave_sweep_overlap(
    const double *edges, size_t edge_value_count,
    const double *query, size_t query_value_count);

#ifdef __cplusplus
}
#endif

#endif
