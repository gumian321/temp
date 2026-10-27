/* Geometry2D::segment_intersects_circle and Rect2::intersects adapted from
 * Godot 4.6.3-stable, core/math/geometry_2d.h:214-245 and rect2.h:49-83.
 * https://github.com/godotengine/godot/tree/4.6.3-stable/core/math
 *
 * Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
 * Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
#include "kernel.h"
#include <float.h>
#include <math.h>

#if defined(__FAST_MATH__) || (defined(__FINITE_MATH_ONLY__) && __FINITE_MATH_ONLY__ > 0)
#error "The sweep kernel requires strict floating-point arithmetic."
#endif
#if defined(_MSC_VER)
#pragma float_control(precise, on)
#pragma fp_contract(off)
#else
#pragma STDC FP_CONTRACT OFF
#endif

_Static_assert(sizeof(float) == 4 && FLT_RADIX == 2 && FLT_MANT_DIG == 24,
    "Godot standard-precision float32 is required");
_Static_assert(sizeof(double) == 8 && DBL_MANT_DIG == 53,
    "GDScript float64 is required");
_Static_assert(FLT_EVAL_METHOD == 0, "Intermediate arithmetic must retain its declared precision");

typedef struct Vec2 { float x, y; } Vec2;
typedef struct Rect { Vec2 position, size; } Rect;

static Vec2 vec(const double *p) { Vec2 v = {(float)p[0], (float)p[1]}; return v; }
static Vec2 add(Vec2 a, Vec2 b) { Vec2 v = {a.x + b.x, a.y + b.y}; return v; }
static Vec2 sub(Vec2 a, Vec2 b) { Vec2 v = {a.x - b.x, a.y - b.y}; return v; }
static Vec2 scale(Vec2 a, float b) { Vec2 v = {a.x * b, a.y * b}; return v; }
static float dot(Vec2 a, Vec2 b) {
    /* Volatile products prevent contraction even if an inliner ignores the
     * standard FP_CONTRACT pragma. Each is rounded before the addition. */
    volatile float x = a.x * b.x, y = a.y * b.y;
    return x + y;
}
static int finite_vec(Vec2 v) { return isfinite(v.x) && isfinite(v.y); }
static int float_component(double v) { return isfinite(v) && v >= -FLT_MAX && v <= FLT_MAX; }
static int rect_intersects(Rect a, Rect b) {
    if (a.position.x >= b.position.x + b.size.x) return 0;
    if (a.position.x + a.size.x <= b.position.x) return 0;
    if (a.position.y >= b.position.y + b.size.y) return 0;
    if (a.position.y + a.size.y <= b.position.y) return 0;
    return 1;
}

static float segment_intersects_circle(Vec2 from, Vec2 to, Vec2 center, float radius) {
    Vec2 line_vec = sub(to, from);
    Vec2 vec_to_line = sub(from, center);
    float a = dot(line_vec, line_vec);
    float b = 2 * dot(vec_to_line, line_vec);
    volatile float radius_squared = radius * radius;
    float c = dot(vec_to_line, vec_to_line) - radius_squared;
    volatile float bb = b * b, four_a = 4 * a;
    volatile float four_ac = four_a * c;
    float sqrtterm = bb - four_ac;
    /* Additional invalid/degenerate guard; finite production sweeps follow
     * Godot's exact root order and float32 operations below. */
    if (!(a > 0) || !isfinite(a) || !isfinite(b) || !isfinite(c) || !isfinite(sqrtterm) || sqrtterm < 0) return -1;
    sqrtterm = sqrtf(sqrtterm);
    float res1 = (-b - sqrtterm) / (2 * a);
    float res2 = (-b + sqrtterm) / (2 * a);
    if (res1 >= 0 && res1 <= 1) return res1;
    if (res2 >= 0 && res2 <= 1) return res2;
    return -1;
}

static double contour_time(const double *edge, Vec2 start, Vec2 delta, Vec2 finish, double radius) {
    Vec2 a = vec(edge), b = vec(edge + 2), edge_delta = vec(edge + 4), normal = vec(edge + 6);
    double earliest = INFINITY;
    double speed = (double)dot(normal, delta);
    if (isfinite(speed) && speed < -0.0000001) {
        double time = (radius - (double)dot(normal, sub(start, a))) / speed;
        if (isfinite(time) && time >= 0 && time <= 1) {
            /* GDScript's double scalar is converted to real_t before each
             * Vector2 multiply; each Vector2 operation rounds to float32. */
            Vec2 contact = sub(sub(add(start, scale(delta, (float)time)), scale(normal, (float)radius)), a);
            double along = (double)dot(contact, edge_delta) / edge[8];
            if (isfinite(along) && along >= 0 && along <= 1) earliest = time;
        }
    }
    if (radius > 0) {
        double radius_squared = radius * radius;
        for (int i = 0; i < 2; ++i) {
            Vec2 vertex = i == 0 ? a : b;
            Vec2 offset = sub(start, vertex);
            double distance_squared = (double)dot(offset, offset);
            if (!isfinite(distance_squared) || distance_squared < radius_squared) continue;
            double time = (double)segment_intersects_circle(start, finish, vertex, (float)radius);
            if (time >= 0 && time <= 1 && time < earliest) earliest = time;
        }
    }
    return earliest;
}

CaveSweepHit cave_sweep_scan(const double *edges, size_t edge_value_count, const double *query, size_t query_value_count) {
    CaveSweepHit result = {-1, INFINITY};
    if (!query || query_value_count != CAVE_SWEEP_QUERY_SIZE ||
        edge_value_count % CAVE_SWEEP_EDGE_STRIDE != 0 ||
        (edge_value_count && !edges) ||
        edge_value_count > SIZE_MAX / sizeof(double) ||
        edge_value_count / CAVE_SWEEP_EDGE_STRIDE > INT64_MAX) return result;
    for (size_t i = 0; i < CAVE_SWEEP_QUERY_SIZE; ++i) {
        if (!float_component(query[i])) return result;
    }
    if (query[7] < 0 || query[8] < 0) return result;
    Vec2 start = vec(query), delta = vec(query + 2), finish = add(start, delta);
    Rect query_rect = {vec(query + 5), vec(query + 7)};
    if (!finite_vec(finish) || !finite_vec(add(query_rect.position, query_rect.size))) return result;
    for (size_t offset = 0; offset < edge_value_count; offset += CAVE_SWEEP_EDGE_STRIDE) {
        const double *edge = edges + offset;
        int valid = isfinite(edge[8]) && edge[8] > 0;
        for (size_t i = 0; i < CAVE_SWEEP_EDGE_STRIDE && valid; ++i) {
            if (i != 8 && !float_component(edge[i])) valid = 0;
        }
        if (!valid || edge[11] < 0 || edge[12] < 0) continue;
        Rect bounds = {vec(edge + 9), vec(edge + 11)};
        if (!finite_vec(add(bounds.position, bounds.size)) || !rect_intersects(bounds, query_rect)) continue;
        double time = contour_time(edge, start, delta, finish, query[4]);
        if (time < result.time) {
            result.index = (int64_t)(offset / CAVE_SWEEP_EDGE_STRIDE);
            result.time = time;
        }
    }
    return result;
}

/* Adapted from the same Godot version: geometry_2d.h:101-116,
 * Rect2::grow_by (rect2.h:203-208), and Rect2::has_point (169-190). */
static Vec2 closest_point_to_segment(Vec2 point, Vec2 a, Vec2 b) {
    Vec2 p = sub(point, a), n = sub(b, a);
    float l2 = dot(n, n);
    if (l2 < 1e-20f) return a;
    float d = dot(n, p) / l2;
    if (d <= 0.0f) return a;
    if (d >= 1.0f) return b;
    return add(a, scale(n, d));
}

int64_t cave_sweep_overlap(const double *edges, size_t edge_value_count, const double *query, size_t query_value_count) {
    if (!query || query_value_count != CAVE_SWEEP_OVERLAP_QUERY_SIZE ||
        edge_value_count % CAVE_SWEEP_EDGE_STRIDE != 0 ||
        (edge_value_count && !edges) ||
        edge_value_count > SIZE_MAX / sizeof(double) ||
        edge_value_count / CAVE_SWEEP_EDGE_STRIDE > INT64_MAX) return -1;
    for (size_t i = 0; i < CAVE_SWEEP_OVERLAP_QUERY_SIZE; ++i) {
        if (!float_component(query[i])) return -1;
    }
    double radius = query[2];
    if (radius <= 0) return -1;
    Vec2 point = vec(query);
    float amount = (float)radius;
    volatile float twice_amount = amount * 2;
    if (!isfinite(twice_amount)) return -1;
    double radius_squared = radius * radius;
    for (size_t offset = 0; offset < edge_value_count; offset += CAVE_SWEEP_EDGE_STRIDE) {
        const double *edge = edges + offset;
        int valid = isfinite(edge[8]) && edge[8] >= 0;
        for (size_t i = 0; i < CAVE_SWEEP_EDGE_STRIDE && valid; ++i) {
            if (i != 8 && !float_component(edge[i])) valid = 0;
        }
        if (!valid || edge[11] < 0 || edge[12] < 0) continue;
        Rect bounds = {vec(edge + 9), vec(edge + 11)};
        bounds.position.x -= amount;
        bounds.position.y -= amount;
        bounds.size.x += twice_amount;
        bounds.size.y += twice_amount;
        Vec2 end = add(bounds.position, bounds.size);
        if (!finite_vec(bounds.position) || !finite_vec(bounds.size) || !finite_vec(end)) continue;
        if (point.x < bounds.position.x || point.y < bounds.position.y ||
            point.x >= end.x || point.y >= end.y) continue;
        Vec2 closest = closest_point_to_segment(point, vec(edge), vec(edge + 2));
        if (!finite_vec(closest)) continue;
        Vec2 difference = sub(closest, point);
        double distance_squared = (double)dot(difference, difference);
        if (isfinite(distance_squared) && distance_squared <= radius_squared)
            return (int64_t)(offset / CAVE_SWEEP_EDGE_STRIDE);
    }
    return -1;
}
