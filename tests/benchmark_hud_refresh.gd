extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var hud=load("res://scripts/battle_hud.gd")
 var meter=hud.Meter.new("armor",Color.WHITE,Vector2(244,38))
 root.add_child(meter)
 meter.reading(75,100,"75 / 100")
 var theme_events=[0]
 meter.amount.theme_changed.connect(func():theme_events[0]+=1)
 var start=Time.get_ticks_usec()
 for i in 10000:meter.reading(75,100,"75 / 100")
 var meter_us=Time.get_ticks_usec()-start
 var ui=load("res://scripts/source_ui.gd").new()
 root.add_child(ui)
 var label=Label.new();label.set_meta("extent",Vector2(100,24));label.text="01:00";ui.add_child(label);ui.labels["test"]=label
 ui.fit_label(label)
 start=Time.get_ticks_usec()
 for i in 10000:ui.set_text("test","01:00")
 print(JSON.stringify({"meter_10000_us":meter_us,"meter_theme_events":theme_events[0],"source_text_10000_us":Time.get_ticks_usec()-start}))
 meter.queue_free();ui.queue_free();quit()
