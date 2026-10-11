extends SceneTree
const Net=preload("res://game/network.gd")
var net: Node
var host:=false
var reverse:=false
var port:=28010
var output:="/tmp/comedy.json"
var begun:=0
var case_started:=0
var ended_at:=0
var case_number:=-1
var sent:={}
var reports:Array=[]
var stages:Array=[]
var stage_seen:={}
var disconnected:=false
var reconnected:=false
var returned:=false
var motion:=false
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg=="--host":host=true
  if arg=="--reverse":reverse=true
  if arg.begins_with("--port="):port=int(arg.trim_prefix("--port="))
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 net=Net.new();net.name="Network";root.add_child.call_deferred(net);launch.call_deferred()
func launch() -> void:
 begun=Time.get_ticks_msec()
 if host:net.host("driver" if reverse else "coach",port)
 else:net.join("127.0.0.1",port)
func begin_case(index: int) -> void:
 net.start_match();net.rules.s.test_case=index;net.rules.s.resource=100
 case_number=index;case_started=Time.get_ticks_msec();sent.clear()
func record_stage(event: Dictionary) -> void:
 if int(event.serial)==0:return
 var key:="%s:%s"%[event.epoch,event.serial]
 if stage_seen.has(key):return
 stage_seen[key]=true;stages.append(event)
func _process(_dt: float) -> bool:
 if begun==0:return false
 var now:=Time.get_ticks_msec()
 var s:Dictionary=net.state
 if host and net.guest!=0 and case_number<0:begin_case(0)
 if not host:
  for event in net.stage_events:record_stage(event)
 if host:record_stage({"epoch":s.epoch,"serial":s.act_serial,"kind":s.act_kind,"phase":s.act_phase,"target":s.act_target})
 if s.phase=="playing" and s.has("test_case"):
  var test_case:=int(s.test_case)
  if test_case!=case_number:case_number=test_case;sent.clear()
  var kind:=3+test_case/2
  var do_counter:=test_case%2==0
  var cleanup:bool=(s.backlash.any(func(v):return v>0) if net.role=="driver" else s.effects.any(func(v):return v>0))
  net.local_input=[.12 if net.role=="driver" else 0.0,.1,false,cleanup]
  if absf(s.speed)>1:motion=true
  if net.role=="driver" and not sent.has("prank"):
   sent.prank=true;net.action("prank",kind)
   if not host:net._command.rpc_id(1,net.event_seq,int(s.epoch),"prank",kind)
  if net.role=="coach" and do_counter and s.prank==kind and s.windup<1.6 and not sent.has("counter"):
   sent.counter=true;net.action("counter",kind)
  if host and now-case_started>6500:net.rules.s.left=minf(net.rules.s.left,.01)
 if s.phase=="ended" and s.has("test_case") and reports.size()==int(s.test_case):
  var record:={}
  for key in ["test_case","epoch","winner","anger","hits","counters","backfires","repairs","driver_repairs","uses","effects","backlash","resource","x","z"]:record[key]=s[key]
  reports.append(record);ended_at=now
  print("COMEDY_CHECKPOINT ",JSON.stringify(record))
 if host and s.phase=="ended" and reports.size()<6 and now-ended_at>1500:begin_case(reports.size())
 if reports.size()==6:
  if not host and not disconnected and now-ended_at>1700:
   net.leave("");disconnected=true;returned=net.state.act_phase=="idle" and net.state.backlash.all(func(v):return v==0)
  if host and net.guest==0 and s.phase=="room":disconnected=true;returned=s.act_phase=="idle" and s.backlash.all(func(v):return v==0)
  if not host and disconnected and not reconnected and now-ended_at>3500:net.join("127.0.0.1",port);reconnected=true
  if host and disconnected and net.guest!=0:reconnected=true;net.leave("")
 if now-begun>60000:
  var report:={"host":host,"reports":reports,"stages":stages,"motion":motion,"disconnected":disconnected,"reconnected":reconnected,"returned_clean":returned,"duplicates":net.duplicate_events,"queue_peak":net.queue_peak,"snapshot_count":net.snapshot_count}
  FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "));net.leave("");quit()
 return false
