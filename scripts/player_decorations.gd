extends RefCounted
var topology=''
var decorations:Array=[]
var choices:Dictionary={}
var rng=RandomNumberGenerator.new()
func _init():rng.seed=501505
func refresh(player):
 var signature=''
 for p in player.parts:signature+=str(p.cell)+';'
 if signature==topology:return
 topology=signature;decorations.clear()
 var cells={Vector2i(0,0):0,Vector2i(1,0):0,Vector2i(0,1):0,Vector2i(1,1):0}
 for i in range(1,player.parts.size()):cells[player.parts[i].cell]=i
 var empty={}
 for cell in cells:
  for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var at=cell+direction
   if cells.has(at):continue
   if not empty.has(at):empty[at]=[]
   empty[at].append({'direction':direction,'owner':cells[cell]})
 for at in empty:
  var neighbors:Array=empty[at];var directions=neighbors.map(func(n):return n.direction)
  var type=501;var angle=0.0
  match neighbors.size():
   1:
    if not choices.has(at):choices[at]=505 if rng.randf()<0.75 else 504
    type=choices[at]
    angle={Vector2i.UP:0.0,Vector2i.RIGHT:PI/2,Vector2i.LEFT:-PI/2,Vector2i.DOWN:PI}[directions[0]]
   2:
    if directions[0]+directions[1]==Vector2i.ZERO:continue
    type=503
    if Vector2i.DOWN in directions:angle=PI/2 if Vector2i.RIGHT in directions else PI
    else:angle=0.0 if Vector2i.RIGHT in directions else -PI/2
   3:
    type=502
    if Vector2i.UP not in directions:angle=PI
    elif Vector2i.RIGHT not in directions:angle=-PI/2
    elif Vector2i.LEFT not in directions:angle=PI/2
  decorations.append({'cell':at,'owner':neighbors[0].owner,'type':type,'angle':angle})
 choices=choices.duplicate()
 for at in choices.keys():
  if not empty.has(at):choices.erase(at)
func pose(decoration:Dictionary,player)->Dictionary:
 var p:Dictionary=player.parts[decoration.owner]
 var origin=Vector2(0.5,0.5) if decoration.owner==0 else Vector2(p.cell)
 var delta=Vector2(decoration.cell)-origin
 return {'position':p.position+Vector2(-delta.y,delta.x).rotated(p.body_angle)*44,'angle':float(p.body_angle)+PI/2-float(decoration.angle)}
