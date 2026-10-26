extends SceneTree
var checks=[]
func check(ok:bool,name:String):checks.append({'name':name,'passed':ok})
func _initialize():call_deferred('execute')
func execute():
 var db=load('res://scripts/source_db.gd').new()
 var state=load('res://scripts/render_state.gd')
 var source=[{'sprite':'a','angle':0,'presentation':{'choices':[{'group':'test','index':0,'count':2}]}},{'sprite':'b','angle':0,'presentation':{'choices':[{'group':'test','index':1,'count':2}]}},{'sprite':'c','angle':0,'presentation':{'active':false}}]
 check(state.instantiate(source,42).size()==1,'Exactly one source random branch; inactive objects hidden')
 var p=load('res://scripts/centipede.gd').new(db);var dec=load('res://scripts/player_decorations.gd').new();dec.refresh(p)
 check(dec.decorations.size()==8,'Source 2x2 HQ has eight adjacent decoration cells')
 var valid=true
 for d in dec.decorations:valid=valid and not p.occupied(d.cell) and dec.pose(d,p).position.is_finite()
 check(valid,'Decorations occupy only empty adjacent cells and have finite centipede attachment poses')
 var a={'angle':0,'presentation':{'rotation_speed':90,'arrow':{'index':0,'count':4,'duration':.5}}}
 check(is_equal_approx(state.angle(a,1),-PI/2),'Source auto rotation converted from Unity handedness')
 check(is_equal_approx(state.color(a,.5).a,1) and is_equal_approx(state.color(a,1.5).a,.25),'Source movement arrow brightens then fades in sequence')
 var fx=load('res://scripts/particle_effects.gd').new();root.add_child(fx);fx.setup(db)
 var bindings=0
 for values in fx.engine_definitions.values():bindings+=values.size()
 check(bindings==109,'All 109 source Engine attachments imported')
 check(fx.definitions['505'][0]._additive and fx.definitions['505'][1]._additive,'Unity built-in shader 202 uses additive particle blending')
 check(not fx.definitions['505'][0].local_space and fx.definitions['505'][1].local_space,'Engine world trail and local sparks retain source simulation spaces')
 fx.sync_engines([{'key':'engine','position':Vector2(20,30),'angle':.2,'active':true,'boost':true}],.25)
 check(fx.engines.engine.nodes.size()==2 and is_equal_approx(fx.engines.engine.size,.6),'Source engine children and boost-size transition')
 fx.sync_engines([],0);await process_frame
 check(fx.engines.is_empty(),'Removed engine attachments release emitters')
 fx.clear();fx.queue_free();await process_frame
 var store=load('res://scripts/save_store.gd').new(db);store.path='user://presentation-save.json';store.fresh()
 var research=load('res://scripts/research_ui.gd').new();root.add_child(research);research.setup(db,store,func():pass,func():pass)
 var before=research.pan;var buttons=research.node_buttons.values()
 buttons[0].grab_focus();check(research.pan==before,'Mouse focus leaves research nodes at their click position')
 research.controller_navigation=true;buttons[1].grab_focus()
 check(root.gui_get_focus_owner()==buttons[1] and research.world.get_global_rect().encloses(buttons[1].get_global_rect()),'Keyboard/controller focus brings the complete selected research node into the visible tree viewport')
 research.queue_free();await process_frame
 var ok=checks.all(func(c):return c.passed)
 FileAccess.open('res://artifacts/presentation-test-report.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'passed':ok},'\t'));print(JSON.stringify(checks));quit(0 if ok else 1)
