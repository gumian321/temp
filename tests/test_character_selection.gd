extends "res://tests/test_centipede_scene.gd"
func settle():
 for i in 4:await process_frame
func skill_press():
 var focus=root.gui_get_focus_owner()
 if focus!=null:focus.release_focus()
 var motion=InputEventMouseMotion.new();motion.position=Vector2(780,480);motion.global_position=motion.position;Input.parse_input_event(motion)
 Input.warp_mouse(Vector2(780,480));await settle()
 var press=InputEventKey.new();press.physical_keycode=KEY_SPACE;press.keycode=KEY_SPACE;press.pressed=true;Input.parse_input_event(press);await settle()
 press=press.duplicate();press.pressed=false;Input.parse_input_event(press);await settle()
func execute():
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1440,900)
 game=load("res://main.tscn").instantiate();root.add_child(game);await settle();game.set_process(false)
 game.save.path="user://character-selection-isolated.json";game.save.fresh();game.save.state.settings.skip_boss=true
 await capture("character-00-home")
 var home_nest_buttons=game.panel.find_children("*","Button",true,false).filter(func(button):return button.is_visible_in_tree() and not button.disabled and button.text==game.db.ui("INSECT NEST","虫巢"))
 check(home_nest_buttons.size()==1,"Home exposes exactly one enabled Nest button")
 if home_nest_buttons.size()!=1:quit(1);return
 await click_at(home_nest_buttons[0].get_global_rect().get_center());await settle()
 check(game.screen=="characters","Home Nest button opens character selection")
 if game.screen!="characters":quit(1);return
 await capture("character-01-locked-nest")
 var nest=game.panel.get_child(0)
 check(nest.cards.keys()==["centipede","spider"],"Nest displays only two active characters")
 check(is_equal_approx(nest.cards.centipede.position.x,1440.0-nest.cards.spider.position.x-nest.cards.spider.size.x),"Two roster cards are horizontally centered")
 check(not visible_text(nest).contains("甲虫"),"Retired character and challenge do not appear in Nest")
 for id in nest.cards:
  var card=nest.cards[id];var portrait=card.get_child(0)
  var texture=preload("res://scripts/character_art.gd").portrait(id)
  check(texture!=null and texture.get_width()>0 and texture.get_height()>0,"Generated portrait asset loads: "+id)
  check(portrait is TextureRect and portrait.size==Vector2(380,244) and card.get_global_rect().encloses(portrait.get_global_rect()),"Actual portrait fits its card: "+id)
 nest.choose("spider");check(game.save.state.selected_character=="centipede","Locked character cannot be selected")
 check(nest.unlock_text("spider").contains("0 / 3"),"Locked spider shows actual challenge progress")
 game.begin_run();await settle()
 while game.deployment_active:await process_frame
 game.set_process(false)
 for i in 6:game.player.install_module(game.db.named("Core_Gun_Gatling").id,i+1)
 await skill_press();game.battle_hud.refresh();await capture("character-02-centipede-coil")
 check(game.player.coil_active,"Real Space input starts centipede coil")
 check(game.player.character_id=="centipede","Default run retains centipede")
 check(game.save.character_run_support_count()==0,"New run resets current support challenge")
 var support:Dictionary={}
 for reward in game.db.kind("BlockReward"):
  if preload("res://scripts/character_roster.gd").is_support(game.db,str(reward.blockCore)):support=reward;break
 game.save.state.unlocked.append(support.id)
 for i in 3:
  game.run.rewards.enqueue(true);game.run.offers=[support]
  check(game.run.take_reward(support),"Support acquisition accepted "+str(i))
  check(not game.run.take_reward(support),"Stale support reward rejected "+str(i))
 check(game.save.character_unlocked("spider"),"Single-run support challenge unlocks playable spider")
 game.show_characters();await settle();nest=game.panel.get_child(0);nest.choose("spider")
 check(game.run.notifications.is_empty() and game.popup_text.queue.is_empty(),"Leaving the run clears stale unlock notices")
 await capture("character-03-selected-spider")
 for dimensions in [Vector2i(1280,720),Vector2i(1440,900)]:
  root.size=dimensions;await settle()
  check(nest.cards.values().all(func(card):return root.get_visible_rect().encloses(card.get_global_rect()) and card.get_global_rect().encloses(card.get_child(0).get_global_rect())),"Roster cards and portraits fit "+str(dimensions))
  await capture("character-roster-"+str(dimensions.x))
 check(game.player.character_id=="centipede","Menu choice does not mutate prior run body")
 game.begin_run();await settle()
 while game.deployment_active:await process_frame
 game.set_process(false)
 check(game.player.character_id=="spider" and game.player.module_cap()==32,"Next run snapshots selected spider")
 check(game.battle_hud.modules.amount.text=="0 / 32","Compact HUD counts occupied mounts rather than fixed body nodes")
 game.show_build();await settle()
 await capture("character-05-spider-hardpoints")
 check(game.build_ui.segment_buttons.is_empty() and game.build_ui.insert_targets.size()==8,"Spider assembly exposes eight empty leg growth targets")
 var core=game.db.named("Core_Gun_Gatling").id
 game.player.pending.append(core)
 game.build_ui.drop({"kind":"mount","before":8},{"kind":"inventory","index":0,"id":core});await settle()
 check(game.player.part_at(8)>0 and game.player.parts.size()==2,"Installing uses exact fixed hardpoint 8")
 while game.player.parts.size() < 33:game.player.append_segment(core)
 var replacement=game.db.named("Core_Gun_Cannon").id
 game.player.pending.append(replacement);game.build_ui.rebuild()
 game.build_ui.drop({"kind":"mount","before":8},{"kind":"inventory","index":0,"id":replacement});await settle()
 check(game.player.parts.size()==33 and game.player.parts[game.player.part_at(8)].id==core and game.player.pending==[replacement],"Full spider leg protects mounted towers and retains pending reward")
 game.show_game();await settle()
 for i in 3:
  game.combat.spawn(game.db.pool["250"],game.player.head+Vector2(170+i*60,30+i*25))
  var enemy=game.combat.enemies.back();enemy.warp=0.0;enemy.damageable=true;enemy.active=true
 await skill_press();game.battle_hud.refresh();await capture("character-04-spider-threads")
 check(game.combat.character_abilities.state().cooldown>0,"Space triggers character skill during play")
 check(not game.combat.character_abilities.state().threads.is_empty(),"Spider skill connects real enemy targets")
 game.show_pause();var previous=game.combat.character_abilities.state().cooldown
 await skill_press()
 check(game.combat.character_abilities.state().cooldown==previous,"Paused UI blocks character skill")
 check(InputMap.action_get_events("character_skill").any(func(e):return e is InputEventJoypadButton and e.button_index==JOY_BUTTON_Y),"Controller Y shares skill action")
 game.combat.boss_kills=1;game.run.track_character_bosses()
 check(not game.save.character_unlocked("beetle"),"Boss kill cannot unlock retired character")
 game.run.track_character_bosses();check(game.save.state.roster_progress.boss_kills==1,"Repeated observation cannot double count a boss")
 check(not game.save.select_character("beetle") and game.save.state.selected_character=="spider","Retired character selection rejected")
 game.cursor_system.shutdown();game.audio_system.shutdown();game.particle_effects.clear();game.queue_free();await settle()
 var report={"checks":checks,"captures":captures,"passed":checks.all(func(c):return c.passed)}
 FileAccess.open("res://artifacts/character-selection-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if report.passed else 1)
