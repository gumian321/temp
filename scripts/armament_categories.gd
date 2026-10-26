extends RefCounted
## Shared presentation categories for the evolution map and reward cards.
const SECTIONS=[
 {"id":"direct","zh":"直射","en":"DIRECT","hint":"针簇 · 散射 · 精确 · 追踪","variants":["gatling","shotgun","sniper","flak","rocket"]},
 {"id":"area","zh":"范围","en":"AREA","hint":"爆破 · 布雷 · 区域覆盖","variants":["cannon","nuke","mine","mine_spawner"]},
 {"id":"sustain","zh":"持续","en":"SUSTAIN","hint":"喷流 · 毒区 · 往返切割","variants":["flame","toxin","boneblade"]},
 {"id":"control","zh":"控制","en":"CONTROL","hint":"连锁 · 减速 · 牵引 · 击退","variants":["tesla","emp","blackhole","sonic"]},
 {"id":"summon","zh":"召唤","en":"SUMMON","hint":"猎蜂 · 寄生幼虫","variants":["drone_bay","parasite"]}]
const SUPPORT={"id":"support","zh":"通用支援","en":"SUPPORT","hint":"防御 · 修复 · 能量 · 弹丸改造"}
static func category(db,value:Dictionary)->Dictionary:
 var variant=db.armament_variant(value)
 variant={"drone_unit":"drone_bay","mine_unit":"mine"}.get(variant,variant)
 for section in SECTIONS:
  if variant in section.variants:return section
 return SUPPORT

# The research map and reward cards share broad groups and concrete effect tags.
const REWARD_LABELS={
 "gatling":["连发射击","RAPID FIRE"],"shotgun":["扇形散射","SPREAD SHOT"],
 "sniper":["远程狙击","SNIPER SHOT"],"flak":["集群齐射","CLUSTER SHOT"],"rocket":["追踪攻击","HOMING SHOTS"],
 "cannon":["范围爆炸","AREA BLAST"],"nuke":["范围爆炸","AREA BLAST"],
 "mine":["布雷爆炸","EGG MINES"],"mine_spawner":["布雷爆炸","EGG MINES"],
 "flame":["持续喷射","FLAME STREAM"],"toxin":["持续毒伤","POISON FIELD"],"boneblade":["回旋切割","RETURN BLADE"],
 "tesla":["连锁牵引","CHAIN PULL"],"emp":["减速控制","SLOW ENEMIES"],
 "blackhole":["范围牵引","AREA PULL"],"sonic":["击退控制","KNOCKBACK"],
 "drone_bay":["召唤猎蜂","WASP SWARM"],"parasite":["寄生召唤","BROOD SWARM"],
 "repair_bay":["召唤修复","REPAIR SWARM"],"repair":["修复体节","BODY REPAIR"],
 "scrap_bay":["资源收集","COLLECT SCRAP"],"shield":["护盾防御","SHIELD"],
 "fuel":["能量补给","ENERGY SUPPLY"],"cloak":["隐蔽保护","CLOAK"],
 "wall":["装甲防御","ARMOR"],"pack":["进化补给","SUPPLIES"],
 "chip_shrapnel":["弹丸分裂","SPLIT SHOTS"],"chip_exploding":["爆炸改造","BLAST SHOTS"],
 "chip_piercing":["弹丸穿透","PIERCE SHOTS"],"chip_chain":["弹丸连锁","CHAIN SHOTS"],
 "chip_mammoth":["弹丸强化","BOOST SHOTS"],"chip_control":["手动瞄准","MANUAL AIM"]}
const REWARD_COLORS={
 "direct":Color("a6d4f5"),"area":Color("efc18b"),"sustain":Color("edb09a"),
 "control":Color("cbb8ee"),"summon":Color("b4d99e"),"support":Color("a5d8c2")}
static func reward_badge(db,value:Dictionary)->Dictionary:
 var variant=db.armament_variant(value)
 variant={"drone_unit":"drone_bay","mine_unit":"mine","repair_drone":"repair_bay","scrap_drone":"scrap_bay"}.get(variant,variant)
 var names:Array=REWARD_LABELS.get(variant,["通用强化","SUPPORT"])
 if variant.is_empty():
  match str(value.get("class","")):
   "PercentBasicReward":names=["属性强化","STAT BOOST"]
   "CrusedReward":names=["代价强化","TRADE-OFF"]
   "CountBasicReward":names=["操作次数","ACTION USES"]
 var section=category(db,value)
 return {"text":db.ui(str(names[1]),str(names[0])),"category":db.ui(str(section.en),str(section.zh)),"color":REWARD_COLORS[str(section.id)]}
