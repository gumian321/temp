# Round 14 shader QA

Final frozen-build regression/native validation complete: True.

Frozen production hashes unchanged: True. Same simulation signature across all six runs: True.

## Native paired performance

| Metric (median across 3 runs) | Before | After | Change |
|---|---:|---:|---:|
| frame_ms p50 | 80.531 | 97.025 | +20.5% |
| frame_ms p95 | 95.203 | 113.466 | +19.2% |
| simulation_prepare_ms p50 | 20.439 | 20.727 | +1.4% |
| simulation_prepare_ms p95 | 25.211 | 25.613 | +1.6% |
| main_draw_build_ms p50 | 13.053 | 17.746 | +36.0% |
| main_draw_build_ms p95 | 16.630 | 21.826 | +31.2% |
| draw_calls p50 | 1862.000 | 1864.000 | +0.1% |
| draw_calls p95 | 2183.000 | 2184.000 | +0.0% |

## Paired frame changes (controls local host drift)

| Pair | p50 before → after ms | p50 change | p95 change |
|---|---:|---:|---:|
| 1 | 79.652 → 97.025 | +21.8% | +26.5% |
| 2 | 86.877 → 95.879 | +10.4% | +9.1% |
| 3 | 80.531 → 98.145 | +21.9% | +21.0% |
Median within-pair frame change: {"p50": 21.811128408577307, "p95": 20.998133830978393, "mean": 21.066467782125752}.

## Conditions and limits

Interleaved before1/after1/before2/after2/before3/after3 in the same time window. Isolated native X11/OpenGL Godot 4.6.3, LP_NUM_THREADS=3, identical 60 warmup + 180 measured fixed-step frames, 31 modules / 64 durable enemies / production projectile floor256. No concurrent heavy test during paired runs.

- llvmpipe is CPU software rasterization, not a physical user GPU. Native shader execution is real but timings are cloud-host-only.
- Driver warned VSync mode cannot be changed; reported mode alone does not guarantee compositor behavior.
- Frame wall time includes game script, draw construction, renderer, window/compositor pacing. It is not an isolated GPU timer.
- simulation_prepare_ms excludes most deferred rendering; main_draw_build_ms is main _draw command construction, not every child draw/GPU operation.
- The optimized direct-RID path moves command submission from deferred child _draw callbacks into main _draw. Its main_draw_build_ms scope therefore grows; compare end-to-end frame_ms rather than interpreting that stage delta alone as net CPU cost.
- No reduced enemy/projectile density, no disabling effects; matched deterministic signatures and populations checked.
- Movie frame sampling is fixed simulation time, not a benchmark screen recording.
- Intermediate two-lane implementation measurements are discarded and stored separately.

## Functional and native checks

- round14-full-regression.json: 91/91 suites pass.
- round14-enemy-motion.json: 1/1 suites pass.
- round14-native-shaders-final.json: 4/4 suites pass.
- round14-native-foreground.json: 1/1 suites pass.
- shader-scene-report.json: 99/99 assertions pass. Production material batches and production drawing entrypoints, fixed geometry/lifetimes/textures. Only uniform clock changes. Native OpenGL, no headless fallback.
- passive-shader-pixels-report.json: 66/66 assertions pass. Six production instanced materials, original atlas and fixed per-instance transforms/state. Only shader sim_time changes; no CPU geometry motion.
- living-shader-scene-report.json: 141/141 assertions pass. Production main renderer. Sustain, hit, break and recovery originate from real combat/player state. Fixed isolated save. No gameplay clock advancement during visual segments.
- weapon-shader-showcase-report.json: 518/518 assertions pass. Fourteen real weapon families against stationary controlled targets in the production scene. Preview captures visual behavior; audio is validated separately.

## Exact native previews

- attack-shader-clock-only.mp4: 19 material families, frozen CPU geometry and effect life, only shader clock changes.
- passive-shader-clock-only.mp4: all six fixed MultiMesh effects, only sim_time changes.
- shield-state-sequence.mp4: production main shield sustain → hit → break → recovery.
- all-weapon-production.mp4: 14 real weapon families hitting real controlled targets.

Each MP4 has a corresponding *-video.json with ffprobe dimensions, frame count, duration and capture scope.
