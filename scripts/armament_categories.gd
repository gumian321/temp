extends RefCounted
## Shared presentation categories for the evolution map and reward cards.
const SECTIONS=[
 {"id":"direct","zh":"直射","en":"DIRECT","hint":"针簇 · 散射 · 精确 · 追踪","variants":["gatling","shotgun","sniper","flak","rocket"]},
 {"id":"area","zh":"范围","en":"AREA","hint":"爆破 · 布雷 · 区域覆盖","variants":["cannon","nuke","mine","mine_spawner"]},
 {"id":"sustain","zh":"持续","en":"SUSTAIN","hint":"喷流 · 毒区 · 往返切割","variants":["flame","toxin","boneblade"]},
 {"id":"control","zh":"控制","en":"CONTROL","hint":"连锁 · 减速 · 牵引 · 击退","variants":["tesla","emp","blackhole","sonic"]},
 {"id":"summon","zh":"召唤","en":"SUMMON","hint":"猎蜂 · 寄生幼虫","variants":["drone_bay","parasite"]}]
const SUPPORT={"id":"support","zh":"通用支援","en":"SUPPORT","hint":"防御 · 修复 · 燃料 · 弹丸改造"}
static func category(db,value:Dictionary)->Dictionary:
 var variant=db.armament_variant(value)
 variant={"drone_unit":"drone_bay","mine_unit":"mine"}.get(variant,variant)
 for section in SECTIONS:
  if variant in section.variants:return section
 return SUPPORT
