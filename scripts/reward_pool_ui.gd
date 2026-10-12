extends Control
var db
var save
var view
var config:Dictionary
var entries:Array=[]
var groups:Array=[]
var draft:Dictionary={}
var back:Callable
var sound:Callable
func setup(source,store,on_back:Callable,on_sound:Callable):
 db=source;save=store;back=on_back;sound=on_sound
 view=load('res://scripts/source_ui.gd').new();add_child(view)
 view.setup(db,'MainMenuScene/ResearchesCanvas',action)
 config=db.read_json('ui_layouts')['MainMenuScene/ResearchesCanvas'].components.ToggleResearchUIManager
 for entry in view.components.values():
  if not entry.has('rewardsList') or not entry.has('rewardButton'):continue
  if entry.rewardsList.is_empty():view.show_node(ref(entry,'canvasGroup'),false);continue
  var group=[]
  for reward in entry.rewardsList:group.append(reward.guid)
  groups.append(group);entries.append(entry);draft[group[0]]=group[0] not in save.state.disabled
  var overlay=db.asset(group[0]).get('rewardOverlaySprite','')
  view.show_node(ref(entry,'rewardOverlay'),not str(overlay).is_empty())
  if overlay is String:view.set_image(ref(entry,'rewardOverlay'),overlay)
  var image=view.images.get(ref(entry,'rewardIcon'))
  if image!=null:image.texture=db.reward_sprite(db.asset(group[0]))
  var b=view.buttons.get(ref(entry,'rewardButton'))
  if b!=null:
   for connection in b.pressed.get_connections():b.pressed.disconnect(connection.callable)
   b.pressed.connect(func():
    if save.state.systems.get('ToggleResearches',false):draft[group[0]]=not draft[group[0]];sound.call();refresh())
 refresh()
func ref(entry:Dictionary,key:String)->String:return str(int(entry.get(key,{}).get('fileID',0)))
func refresh():
 var unlocked=save.state.systems.get('ToggleResearches',false)
 var count=0;var available=0
 for i in groups.size():
  var first=groups[i][0];var entry=entries[i];var known=first in save.state.unlocked
  if known:available+=1
  if known and draft[first]:count+=1
  view.show_node(ref(entry,'rewardLock'),not known)
  var node=view.controls.get(ref(entry,'canvasGroup'))
  if node!=null:node.modulate.a=(1.0 if draft[first] else 0.7) if known else 0.25
  var b=view.buttons.get(ref(entry,'rewardButton'))
  if b!=null:b.disabled=not known
 view.show_node(ref(config,'buttonsPanel'),unlocked)
 view.show_node(ref(config,'ResearchPanel'),not unlocked)
 view.show_node(ref(config,'scrapsAmountUI'),not unlocked)
 view.show_node(ref(config,'demoButton'),false)
 view.show_node(ref(config,'backButton'),true)
 view.show_node(ref(config,'playRewardsActivated'),count!=available)
 view.show_node(ref(config,'playRewardsDeActivated'),count==available)
 view.set_text(ref(config,'costText'),str(int(config.researchCost)))
 view.set_text(ref(config,'rewardsCountText'),str(count)+'/5')
 view.buttons[ref(config,'applyButton')].disabled=count<5
 view.buttons[ref(config,'ResearchButton')].disabled=save.state.meta<int(config.researchCost)
func action(method:String,_id:String,_args:Dictionary):
 sound.call()
 match method:
  'BackButton':back.call()
  'ResearchSystem':save.unlock_reward_pool(int(config.researchCost));refresh()
  'ToggleAllButton','ToggleNoneButton':
   if not save.state.systems.get('ToggleResearches',false):return
   for key in draft:draft[key]=method=='ToggleAllButton'
   refresh()
  'ApplyButton':
   if save.apply_reward_pool(groups,draft):back.call()
