extends RefCounted
## Read-only passive presentation. Identity comes from stable part UIDs, never slots.
const UI=preload("res://scripts/game_ui.gd")
const INK=Color("24475c")
const TEAL=Color("4caeac")
const GOLD=Color("d6a54b")
const REPAIR=Color("69b69c")
const PURPLE=Color("9690ce")
const MAX_LINKS=72
const MAX_PULSES=24
var textures:Dictionary={}
var notices:Array=[]
var clock=0.0
var layer:CanvasLayer
var card:PanelContainer
var heading:Label
var detail:Label
var stat_readout:Label
var draw_count=0
var seen_events=0

func setup(owner:Node):
 layer=CanvasLayer.new();layer.layer=6;owner.add_child(layer)
 card=PanelContainer.new();card.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.theme=UI.theme();UI.protect(card);layer.add_child(card)
 var skin=UI.style(Color(UI.BG,.97),Color(INK,.24),10)
 skin.content_margin_left=18;skin.content_margin_right=18;skin.content_margin_top=10;skin.content_margin_bottom=10
 card.add_theme_stylebox_override("panel",skin)
 var box=VBoxContainer.new();box.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_theme_constant_override("separation",3);card.add_child(box)
 heading=Label.new();heading.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;heading.add_theme_font_size_override("font_size",18);heading.add_theme_color_override("font_color",INK);heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(heading)
 detail=Label.new();detail.add_theme_font_size_override("font_size",14);detail.add_theme_color_override("font_color",UI.MUTED);detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size.x=350;detail.max_lines_visible=4;detail.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(detail)
 card.hide()
 stat_readout=Label.new();stat_readout.theme=UI.theme();stat_readout.add_theme_font_size_override("font_size",12);stat_readout.add_theme_color_override("font_color",INK);stat_readout.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(stat_readout)
 var atlas_path="res://assets/ui_overhaul/passive_effects_atlas.png"
 if ResourceLoader.exists(atlas_path):
  var sheet=load(atlas_path)
  var regions=[Rect2(46,22,452,462),Rect2(564,22,409,460),Rect2(1039,30,451,440),Rect2(37,514,463,463),Rect2(531,517,475,460),Rect2(1035,517,478,470)]
  var keys=["shield","armor","repair","chip","boost","cloak"]
  for i in keys.size():
   var texture=AtlasTexture.new();texture.atlas=sheet;texture.region=regions[i];texture.filter_clip=true;textures[keys[i]]=texture

func reset():
 notices.clear();clock=0;seen_events=0
 if is_instance_valid(card):card.hide()

func tick(game,dt:float):
 if game.player==null:return
 if game.player.has_method("take_feedback_events"):
  for event in game.player.take_feedback_events():
   seen_events+=1
   if str(event.get("kind","")) in ["reward","installed","reinforced"]:
    notices.append({"event":event,"left":4.2})
    if notices.size()>4:notices.pop_front()
 if game.screen in ["menu","result","intro"]:
  notices.clear()
 if game.screen=="game":clock+=dt
 if not notices.is_empty() and game.screen!="pause":
  notices[0].left-=dt
  if notices[0].left<=0:notices.pop_front()
 if not is_instance_valid(card):return
 stat_readout.visible=game.screen=="game" and not game.player.stats.is_empty()
 stat_readout.position=Vector2(24,game.get_viewport_rect().size.y-57)
 var stats=stat_fragments(game.db,game.player.stats)
 stat_readout.text="  ·  ".join(stats.slice(0,3))+("  +%d"%(stats.size()-3) if stats.size()>3 else "")
 stat_readout.tooltip_text="\n".join(stats)
 card.visible=not notices.is_empty() and game.screen in ["game","build","rewards"]
 if not card.visible:return
 var event:Dictionary=notices[0].event
 heading.text=str(event.get("title",""))
 if heading.text.is_empty():
  if event.get("reward_class")=="PercentBasicReward":heading.text=stat_name(game.db,str(int(game.db.asset(event.reward_id).rewardType)))
  else:heading.text=game.db.ui("Segment reinforced","体节加固完成") if event.get("kind")=="reinforced" else game.db.ui("Module installed","模块装配完成")
 var status=str(event.get("status","active"))
 var description=status_text(game.db,status)
 var changes:Dictionary=event.get("details",{}).get("stat_changes",{})
 if not changes.is_empty():description=" · ".join(stat_fragments(game.db,changes))
 if event.get("status")=="pending_charge":
  description=charge_text(game.db,str(event.get("details",{}).get("action","wall")),int(event.get("details",{}).get("count",1)))
 if str(event.get("reward_class","")).ends_with("LevelUpReward"):
  description+="\n"+upgrade_summary(game.db,game.db.asset(event.reward_id))
 detail.text=description
 heading.add_theme_color_override("font_color",GOLD if status in ["pending_module","pending_charge","dormant"] else INK)
 card.size=Vector2(400,0)
 card.position=Vector2(24,game.get_viewport_rect().size.y-maxf(70,card.get_combined_minimum_size().y)-72)
 card.modulate.a=minf(1,float(notices[0].left)*3)

static func status_text(db,status:String)->String:
 match status:
  "pending_module":return db.ui("IN RESERVE · Open Armory and place the new segment","待装配 · 打开身体装配，放入新体节")
  "pending_charge":return db.ui("CHARGE READY · Select a segment in Armory to use it","次数已到账 · 在身体装配中选择体节后使用")
  "dormant":return db.ui("UPGRADE STORED · Activates when a matching module is installed","升级已储备 · 装上对应模块后生效")
 return db.ui("ACTIVE · Applied to matching equipment","已生效 · 已应用于对应装备")

func overlay(canvas,key:String,at:Vector2,extent:Vector2,angle:float,alpha:float):
 if not textures.has(key):return
 canvas.draw_set_transform(at,angle)
 canvas.draw_texture_rect(textures[key],Rect2(-extent*.5,extent),false,Color(1,1,1,alpha))
 canvas.draw_set_transform(Vector2.ZERO)

func paint(canvas,player,combat,zoom:float):
 if not player.has_method("passive_state"):return
 draw_count=0
 var links=0
 for i in player.parts.size():
  var state:Dictionary=player.passive_state(i)
  if not state.get("alive",false):continue
  var at:Vector2=canvas.world(state.position)
  if not canvas.get_viewport_rect().grow(240).has_point(at):continue
  var origin:Vector2=canvas.world(player.weapon_origin(i))
  var radius=maxf(18,player.module_size(i)*.5+5)*zoom
  var pulses:Dictionary=state.get("pulses",{})
  var angle=float(player.parts[i].angle)
  if state.get("reinforced",false):
   # Two inset flanks leave the weapon face unobscured, unlike a generic ring.
   overlay(canvas,"armor",origin,Vector2.ONE*radius*2.25,angle,.56)
   for side in [-1,1]:
    var points=PackedVector2Array()
    for v in [Vector2(-.65,side*.8),Vector2(-.3,side*1.04),Vector2(.38,side*1.04),Vector2(.7,side*.75)]:points.append(origin+v.rotated(angle)*radius)
    canvas.draw_polyline(points,Color(INK,.85),3*zoom,true)
    canvas.draw_polyline(points,Color(GOLD,.86),1.3*zoom,true)
  if float(state.get("shield_capacity",0))>0:
   var reach:float=combat.shield_range(i)*zoom
   if float(state.get("shield",0))>0 and state.get("active",false):
    var strength=clampf(float(state.shield)/maxf(1,float(state.shield_capacity)),0,1)
    overlay(canvas,"shield",at,Vector2.ONE*reach*2,0,.10+strength*.10)
    for sector in 6:canvas.draw_arc(at,reach,sector*TAU/6+.025,(sector+1)*TAU/6-.025,14,Color(TEAL,.18+strength*.25),1.3*zoom,true)
    canvas.draw_arc(at,reach,-PI/2,-PI/2+TAU*strength,64,Color(TEAL,.55),1.8*zoom,true)
   elif state.get("shield_broken",false):
    for sector in 4:canvas.draw_arc(at,reach,sector*PI/2+.25,sector*PI/2+.55,5,Color(INK,.15),zoom,true)
   if float(pulses.get("shield_break",0))>0 and draw_count<MAX_PULSES:
    draw_count+=1
    var fade=minf(1,float(pulses.shield_break)*2)
    for sector in 8:
     var a=sector*TAU/8
     canvas.draw_line(at+Vector2.from_angle(a)*reach,at+Vector2.from_angle(a+.05)*(reach+12*zoom*(1-fade)),Color(GOLD,fade*.85),2*zoom,true)
   if float(pulses.get("shield_hit",0))>0 and state.get("active",false):
    canvas.draw_arc(at,reach,-PI*.25,PI*.75,32,Color(TEAL,minf(.75,pulses.shield_hit*4)),2.8*zoom,true)
   if float(pulses.get("shield_recharge",0))>0:
    canvas.draw_arc(at,reach*.96,clock*2,clock*2+PI*1.4,40,Color(TEAL,minf(1,pulses.shield_recharge)),2.5*zoom,true)
  if state.get("cloaked",false):
   overlay(canvas,"cloak",origin,Vector2.ONE*radius*2.4,angle,.35)
   for strand in 3:
    var offset=(strand-1)*radius*.7
    canvas.draw_line(origin+Vector2(-radius,offset+sin(clock*2+strand)*3*zoom),origin+Vector2(radius,offset),Color(PURPLE,.24),1.5*zoom,true)
  for target in state.get("chip_links",[]):
   if links>=MAX_LINKS or int(target)<0 or int(target)>=player.parts.size():break
   links+=1
   var end:Vector2=canvas.world(player.parts[int(target)].position)
   var strength=.22 if float(pulses.get("chip_trigger",0))<=0 else .7
   for n in 5:canvas.draw_line(at.lerp(end,n/5.0),at.lerp(end,(n+.48)/5.0),Color(GOLD,strength),1.3*zoom,true)
   canvas.draw_circle(end,2.1*zoom,Color(GOLD,strength),true,-1,true)
  if float(pulses.get("healed",0))>0 and draw_count<MAX_PULSES:
   draw_count+=1
   overlay(canvas,"repair",origin,Vector2.ONE*radius*2.5,0,minf(.7,pulses.healed))
   for stitch in 3:
    var p=origin+Vector2((stitch-1)*8,-radius-4)*zoom
    canvas.draw_line(p-Vector2(0,4)*zoom,p+Vector2(0,4)*zoom,Color(REPAIR,minf(1,pulses.healed*2)),2*zoom,true)
    canvas.draw_line(p-Vector2(3,0)*zoom,p+Vector2(3,0)*zoom,Color(REPAIR,minf(1,pulses.healed*2)),2*zoom,true)
  for kind in ["upgrade","reward","installed","reinforced","chip_trigger"]:
   var remaining=float(pulses.get(kind,0))
   if remaining<=0 or draw_count>=MAX_PULSES:continue
   draw_count+=1
   var color=GOLD if kind in ["reinforced","chip_trigger"] else TEAL
   var fade=minf(1,remaining*2)
   if kind=="chip_trigger":overlay(canvas,"chip",origin,Vector2.ONE*radius*2.6,0,fade*.7)
   # Four compact acquisition brackets, only on the actual affected module.
   for corner in 4:
    var a=PI/4+corner*PI/2
    var p=origin+Vector2.from_angle(a)*(radius+7*zoom*(1-fade))
    canvas.draw_line(p,p+Vector2.from_angle(a+2.35)*6*zoom,Color(color,fade*.8),2*zoom,true)
    canvas.draw_line(p,p+Vector2.from_angle(a-2.35)*6*zoom,Color(color,fade*.8),2*zoom,true)
  if not state.get("upgrades",[]).is_empty():
   var total_level=0
   for id in state.upgrades:total_level+=int(player.levels.get(id,0))
   for level in mini(3,total_level):
    var mark=origin+Vector2((level-1)*6,radius/zoom+6)*zoom
    canvas.draw_polyline(PackedVector2Array([mark+Vector2(-2,2)*zoom,mark,mark+Vector2(2,2)*zoom]),Color(TEAL,.68),1.5*zoom,true)
  var core:Dictionary=player.effective_core(i)
  if core.get("class")=="FuelCore" and state.get("active",false):
   var fill=clampf(player.fuel/maxf(1,player.max_fuel),0,1)
   var base=origin+Vector2(-12,radius/zoom+12)*zoom
   for pip in 5:
    canvas.draw_line(base+Vector2(pip*6,0)*zoom,base+Vector2(pip*6,4)*zoom,Color(GOLD if player.boost else TEAL,.7 if fill>pip*.2 else .15),2*zoom,true)
  if float(pulses.get("mine_deploy",0))>0 and draw_count<MAX_PULSES:
   draw_count+=1
   var fade=minf(1,float(pulses.mine_deploy)*3)
   for seed in 3:
    var spot=origin+Vector2.from_angle(angle+PI+(seed-1)*.4)*(radius+8*zoom*(1-fade))
    canvas.draw_circle(spot,2.4*zoom,Color(GOLD,fade),true,-1,true)
  if i==0 and player.boost:
   overlay(canvas,"boost",at,Vector2(90,62)*zoom,player.facing.angle(),.35)

 # Actual drone modes, carried salvage and source-linked upgrade ranks.
 for drone in combat.drones:
  if drone.get("docked",false):continue
  var owner=int(drone.get("owner",-1))
  if owner<0 or owner>=player.parts.size() or player.parts[owner].hp<=0:continue
  var at:Vector2=canvas.world(drone.position)
  if not canvas.get_viewport_rect().grow(30).has_point(at):continue
  var mode=str(drone.get("mode","return"))
  if mode=="carry" and drone.get("carrying",false):
   var diamond=PackedVector2Array([at+Vector2(0,7)*zoom,at+Vector2(3,10)*zoom,at+Vector2(0,13)*zoom,at+Vector2(-3,10)*zoom])
   canvas.draw_colored_polygon(diamond,Color(GOLD,.85))
  elif mode=="repair" and player.parts[owner].stun<=0 and not drone.get("target",{}).is_empty() and drone.target.get("feedback_pulses",{}).has("healed") and Vector2(drone.position).distance_to(drone.target.position)<=float(drone.data.get("droneActionRange",0))*48:
   canvas.draw_line(at,canvas.world(drone.target.position),Color(REPAIR,.3),zoom,true)
  var level=0
  for id in player.levels:
   if drone.data.id in player.db.asset(id).get("dronesList",[]):level+=int(player.levels[id])
  for pip in mini(3,level):canvas.draw_circle(at+Vector2((pip-1)*4,-12)*zoom,1.3*zoom,Color(TEAL,.85),true,-1,true)

static func stat_name(db,key:String)->String:
 if key.is_valid_float():key=str(int(key.to_float()))
 var names={"2":["Weapon rate","武器射速"],"3":["Weapon range","武器射程"],"10":["Head health","头部耐久"],"11":["Move speed","移动速度"],"12":["Boost speed","推进速度"],"13":["Head rate","头部射速"],"14":["Head damage","头部伤害"],"15":["Weapon damage","武器伤害"],"16":["Segment health","体节耐久"],"17":["Head range","头部射程"]}
 var pair=names.get(key,[key,key]);return db.ui(pair[0],pair[1])

static func stat_fragments(db,stats:Dictionary)->PackedStringArray:
 var result=PackedStringArray()
 for key in stats:
  if is_zero_approx(float(stats[key])):continue
  result.append(stat_name(db,str(key))+" %+.0f%%"%(float(stats[key])*100))
 return result

static func upgrade_summary(db,reward:Dictionary)->String:
 var fields={"CoreHealthPercent":["Durability","耐久"],"DamagePercent":["Damage","伤害"],"RateOfFirePercent":["Fire rate","射速"],"RangePercent":["Range","射程"],"ShieldHealthPercent":["Shield capacity","护盾容量"],"ShieldRechargeRatePercent":["Shield recharge","护盾回复"],"ShieldRechargeDelayPercent":["Recharge delay","回复延迟"],"ShieldRangePercent":["Shield radius","护盾半径"],"TankCapacityPercent":["Fuel capacity","燃料容量"],"maxMinesCountPercent":["Mine capacity","地雷上限"],"minesRechargeRatePercent":["Mine reload time","布雷间隔"],"enginePowerPercent":["Drone speed","无人机速度"],"efficiencyPercent":["Drone efficiency","无人机效率"],"rangePercent":["Drone range","无人机范围"]}
 var parts=PackedStringArray()
 for key in fields:
  if not reward.has(key) or is_zero_approx(float(reward[key])):continue
  if reward.get("name")=="Reward_LevelUP_MineSpawner" and key=="maxMinesCountPercent":continue
  if reward.get("name")=="Reward_LevelUP_Gun_FlameThrower" and key=="RateOfFirePercent":continue
  parts.append(db.ui(fields[key][0],fields[key][1])+" %+.0f%%"%(float(reward[key])*100))
 if reward.get("addDronesCount",0)!=0:parts.append(db.ui("Bay drones +%d","巢内无人机 +%d")%int(reward.addDronesCount))
 return " · ".join(parts)

static func action_name(db,action:String)->String:
 var names={"wall":["Reinforce","加固"],"swap":["Swap","交换"],"move":["Move","移动"],"duplicate":["Duplicate","复制"]}
 var pair=names.get(action,[action,action]);return db.ui(pair[0],pair[1])

static func charge_text(db,action:String,count:int)->String:
 return action_name(db,action)+db.ui(" +%d charges · Armory → select segment → use","次数 +%d · 身体装配 → 选中体节 → 使用")%count
