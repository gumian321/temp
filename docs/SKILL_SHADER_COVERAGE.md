# Skill shader coverage audit

Scope: catalog-backed live weapons, support modules, chips, deployables and the two selectable character skills. Beetle charge and frontal armor are retired legacy paths and are explicitly excluded; do not re-enable the character.

## Catalog identities (33)

- `gatling` — 蜂尾针簇; source turrets: `Turret_Gun_Gatling`
- `shotgun` — 裂颚; source turrets: `Turret_Gun_Shotgun`
- `cannon` — 爆腹; source turrets: `Turret_Gun_Cannon`
- `flak` — 刺冠; source turrets: `Turret_Gun_Flak`
- `sniper` — 穿喙; source turrets: `Turret_Gun_Sniper`
- `tesla` — 雷须; source turrets: `Turret_Gun_Tesla`
- `emp` — 缄鸣; source turrets: `Turret_Gun_EMP`
- `flame` — 炽嗉; source turrets: `Turret_Gun_FlameThrower`
- `rocket` — 追蛹; source turrets: `Turret_Gun_Rocket`, `Turret_Gun_Rocket_AI`
- `nuke` — 王卵; source turrets: `Turret_Gun_Nuke`
- `sonic` — 振翅; source turrets: `Turret_Gun_SonicWave`
- `blackhole` — 螳涡; source turrets: `Turret_Gun_Black Holer`
- `mine` — 卵环; source turrets: `Turret_Mines`
- `mine_spawner` — 播卵; source turrets: `Turret_Mines Spawner`
- `drone_bay` — 猎蜂巢; source turrets: `Turret_Drones_Attack`, `Turret_Drones_Attack_AI`
- `repair_bay` — 缝蚁巢; source turrets: `Turret_Drones_Engineer`
- `scrap_bay` — 拾蚁巢; source turrets: `Turret_Drones_Scrapper`
- `shield` — 鞘盾; source turrets: `Turret_Shield`
- `repair` — 缝生蜱; source turrets: `Turret_RepairTurret`
- `fuel` — 蜜囊; source turrets: `Turret_FuelTank`
- `cloak` — 隐翅; source turrets: `Turret_Clocking`
- `wall` — 铁鞘; source turrets: `Turret_Wall`
- `pack` — 孵囊; source turrets: `Turret_PackCore`
- `mine_unit` — 裂卵; source turrets: spawned unit / chip
- `drone_unit` — 猎蜂; source turrets: spawned unit / chip
- `repair_drone` — 缝蚁; source turrets: spawned unit / chip
- `scrap_drone` — 拾蚁; source turrets: spawned unit / chip
- `chip_shrapnel` — 裂刺囊; source turrets: spawned unit / chip
- `chip_exploding` — 爆腺; source turrets: spawned unit / chip
- `chip_piercing` — 贯针; source turrets: spawned unit / chip
- `chip_chain` — 跃电脉; source turrets: spawned unit / chip
- `chip_mammoth` — 巨腹; source turrets: spawned unit / chip
- `chip_control` — 统御触角; source turrets: spawned unit / chip

## Core variants

### ProjectileCore (24)

- `HQ_Gun_Gatling`
- `HQ_Gun_SonicWave`
- `HQ_Gun_Sniper`
- `HQ_Gun_EMP`
- `HQ_Gun_Cannon`
- `HQ_Gun_Tesla`
- `HQ_Core_Flak`
- `HQ_Gun_BlackHoler`
- `Core_Gun_Cannon`
- `Core_Gun_Flak`
- `Core_Gun_BlackHoler`
- `Core_Gun_Tesla`
- `Core_Gun_EMP`
- `Core_Gun_Gatling`
- `Core_Gun_Flame Thrower`
- `Core_Gun_SonicWave`
- `Core_Gun_Sniper`
- `Core_AI_Gun_Tesla`
- `Core_AI_Gun_Cannon`
- `Core_AI_Gun_EMP`
- `Core_AI_Gun_Sniper`
- `Core_AI_Gun_Gatling`
- `Core_AI_Gun_Flame Thrower`
- `Core_AI_Gun_Flak`
### BarrageProjectileCore (8)

- `HQ_Gun_Rocket`
- `HQ_Core_Shotgun`
- `HQ_Core_Nuke`
- `Core_Gun_Nuke`
- `Core_Gun_Rocket`
- `Core_Gun_Shotgun`
- `Core_AI_Gun_Rocket`
- `Core_AI_Gun_Shotgun`
### ShieldCore (6)

- `HQ_Core_Shield`
- `Core_Shield`
- `Core_AI_Shield_Large`
- `Core_AI_Shield_Small`
- `Core_AI_Shield_Mid`
- `Core_AI_Shield_Huge`

## Upgrade and fusion coverage

Upgrade ranks are integer stacks, not discrete replacement skill assets. Verify base, rank 1 and a high-stack rank (5), plus fusion levels 1, 2 and 3; assert the same shader route remains attached as range, damage and size change. Do not invent a finite maximum upgrade rank. Chip source values have two levels and require both.

- `Reward_LevelUP_MineField` (MineFieldLevelUpReward): Core_MinesField
- `Reward_LevelUP_Drone_Scrapper` (DroneLevelUpReward): Core_Drones_Scrapper
- `Reward_LevelUP_Shield` (ShieldLevelUpReward): HQ_Core_Shield, Core_Shield
- `Reward_LevelUP_Gun_Cannon` (TurretLevelUpReward): Core_Gun_Cannon, HQ_Gun_Cannon
- `Reward_LevelUP_Gun_Nuke` (TurretLevelUpReward): Core_Gun_Nuke, HQ_Core_Nuke
- `Reward_LevelUP_Gun_Rocket` (TurretLevelUpReward): Core_Gun_Rocket, HQ_Gun_Rocket
- `Reward_LevelUP_Gun_Gatling` (TurretLevelUpReward): Core_Gun_Gatling, HQ_Gun_Gatling
- `Reward_LevelUP_Gun_BlackHole` (TurretLevelUpReward): Core_Gun_BlackHoler, HQ_Gun_BlackHoler
- `Reward_LevelUP_Gun_Tesla` (TurretLevelUpReward): Core_Gun_Tesla, HQ_Gun_Tesla
- `Reward_LevelUP_Gun_SonicWave` (TurretLevelUpReward): Core_Gun_SonicWave, HQ_Gun_SonicWave
- `Reward_LevelUP_Gun_Shotgun` (TurretLevelUpReward): Core_Gun_Shotgun, HQ_Core_Shotgun
- `Reward_LevelUP_Drone_Engineer` (DroneLevelUpReward): Core_Drones_Engineer
- `Reward_LevelUP_Gun_Sniper` (TurretLevelUpReward): Core_Gun_Sniper, HQ_Gun_Sniper
- `Reward_LevelUP_Gun_FlameThrower` (TurretLevelUpReward): Core_Gun_Flame Thrower
- `Reward_LevelUP_Gun_EMP` (TurretLevelUpReward): Core_Gun_EMP, HQ_Gun_EMP
- `Reward_LevelUP_Gun_Flak` (TurretLevelUpReward): Core_Gun_Flak, HQ_Core_Flak
- `Reward_LevelUP_Drone_Attack` (DroneLevelUpReward): Core_Drones_Attack
- `Reward_LevelUP_FuelTank` (FuelTankLevelUpReward): Core_FuelTank
- `Reward_LevelUP_MineSpawner` (MineFieldLevelUpReward): Core_MineSpawner
- `Reward_LevelUP_Wall` (LevelUpReward): Core_Wall

## Lifecycle routes and easily missed paths

- Combat.fire: all 32 projectile cores, friendly and hostile. HQ and AI names share weapon families; sniper maps to rail. Barrage follow-ups must not bypass routing.
- Continuous flame: SpecialSystems.continuous emits short-lived flame effects, without regular bullets. Test both owners and duplicate-owner suppression.
- Projectile bodies: InsectProjectiles.paint and its early-return tongue/viscous branches; muzzle, travel and impact are separate paths. Budget exhaustion must never remove hostile silhouettes.
- Contact: WeaponFX.paint_effect handles hit, shield_hit, viscous_contact and egg_burst. These need surface-anchored shading, rather than only a launch flash.
- Tesla/sniper and chain chip: chain beam effects may hit immediately without a travelling bullet.
- Black hole: travelling seed, hole_birth, SpecialSystems.black_holes persistent suction and hole_collapse. Continuous DPS does not use the regular hit path.
- Mines: mine_arm, main.gd deployed-unit art plus WeaponFX standing halo, contact explosion. Anchored mines and movement-spawned mines differ; destruction/expiry removes their state.
- Drones: attack/repair/scrap bays, both friendly and enemy units, docked exclusion, launch/travel/work/return. Drone projectile has its own family.
- EMP silk and Tesla tendril: InsectAttackFX.paint consumes real control duration and release; removed source, dead target, converted faction, range and stun eligibility must clean up.
- Player shield: initial capacity, directional impact point, depleted break, delay, recharge, stun/destroyed suppression, HQ weapon switching and upgrade-scaled radius.
- Enemy shields: all four size classes and actual shield_left/range, hostile visual identity.
- Passives: repair/healed pulses, armor reinforcement, cloak activation/deactivation, fuel boost, pack module, six chip link/trigger identities. Full-health idle repair must not claim healing.
- Character abilities: centipede request/coil convergence/hold/release and spider target acquisition/moving threads/release. Paused drawing must not advance gameplay timers.

## Verification contract

Tests must exercise the production renderer against an attached shader layer and inspect actual submitted commands or visible MultiMesh instances with a ShaderMaterial. File existence alone is insufficient. Headless checks establish routing/state and resource bounds, not shader compilation or visual quality. A native renderer must compile the shaders and capture multiple times, zoom levels and shield states; retain performance results separately from gameplay correctness.

## Verified runtime evidence

`tests/test_skill_shader_coverage.gd` passed 669 checks on 2026-10-15 with Godot 4.6.3 headless. Output: `artifacts/skill-shader-coverage-report.json`.

- All 32 source projectile cores fired through actual Combat.fire / continuous, both friendly and hostile, at base/rank 1/rank 5 damage and chip configurations. Actual emitted bullets/effects reached the expected ShaderMaterial geometry or art batch.
- All 15 weapon feedback families exercised the 12 supported effect painter routes in both factions; these are renderer lifecycle payload fixtures, not a claim that every family emits every effect kind in gameplay.
- Persistent black holes reached their real painter. Fixed materials reused across 120 frames; new-frame clearing and explicit pause-compatible clocks passed.
- All six ShieldCore variants were equipped and hit from four directions via Combat.hurt_player, then broken, allowed to disappear and recharged through actual battle advancement. All four AI shield sizes additionally received actual Combat.hit_enemy contacts in four directions and exercised hostile presentation, break history and refill history. Enemy break/refill history tests manipulate shield state after real impacts; they do not retest all enemy recharge mechanics.
- Six chip cores, fuel, repair, wall and pack reached their expected real passive MultiMesh modes. Cloak required actual live adjacency and cleared after source destruction. Centipede coil submitted armor mode; spider skill acquired a real enemy, submitted silk and cleared on finish. Both silk and tendril controls attached through the real control system and cleared shader geometry after expiry.
- Tests record passive payloads in a test-only subclass that delegates to the production add method. This is necessary because Godot's dummy headless renderer does not retain MultiMesh getter buffer values. The actual production MultiMesh is still populated and its visible count/material is checked. GPU acceptance of negative custom-data coordinates remains a native-render check.

The exhaustive source lists above are broader than this focused automated suite. Main-scene deployed mine/drone classification, dock/return animation, native shader compilation, per-pixel quality, fusion-size presentation and dense-scene budgets require the accompanying implementation/native QA suites; they are not certified by the 669-check result alone.
