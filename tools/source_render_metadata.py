"""Retain active hierarchy and serialized per-renderer presentation components."""
from pathlib import Path

def extract_metadata(docs, guids):
 gos={d['__id']:d['GameObject'] for d in docs if 'GameObject'in d}
 transforms={d['__id']:d['Transform'] for d in docs if 'Transform'in d}
 parents={t['m_GameObject']['fileID']:transforms.get(t['m_Father']['fileID'],{}).get('m_GameObject',{}).get('fileID',0) for t in transforms.values()}
 cs={};selectors=[];arrows={};renderer_ids={}
 for d in docs:
  if 'SpriteRenderer'in d:renderer_ids[d['__id']]=d['SpriteRenderer']['m_GameObject']['fileID']
  if 'MonoBehaviour'not in d:continue
  c=d['MonoBehaviour'];name=Path(guids.get(c.get('m_Script',{}).get('guid',''),'')).stem
  if not c.get('m_Enabled',1):continue
  cs.setdefault(c['m_GameObject']['fileID'],{})[name]=c
  if name=='GameObjectsSelector':selectors.append((str(d['__id']),[v['fileID'] for v in c['objectsList']]))
  if name=='MovementArrowsController':
   for i,v in enumerate(c['arrowsObjects']):arrows[v['fileID']]={'index':i,'count':len(c['arrowsObjects']),'duration':[.25,.5,1,1.5,3,6][c.get('tweenDuration',1)]}
 arrow_go={renderer_ids[k]:v for k,v in arrows.items() if k in renderer_ids}
 result={}
 for go in gos:
  chain=[];cur=go
  while cur:chain.append(cur);cur=parents.get(cur,0)
  choices=[{'group':sid,'index':members.index(member),'count':len(members)} for sid,members in selectors for member in members if member in chain]
  controlled={member for _,members in selectors for member in members}
  active=all(gos.get(v,{}).get('m_IsActive',1) or v in controlled for v in chain[:-1])
  local=cs.get(go,{});auto=local.get('AutoRotator',{});random=local.get('RandomRotator',{})
  result[go]={'active':bool(active),'choices':choices,'sprites':[s['guid'] for s in local.get('SpriteRandomSelector',{}).get('spritesList',[])],'rotation_speed':auto.get('speed',25) if auto.get('IsRotating',False) else 0,'random_rotation':bool(random.get('rotateVector',{}).get('z',0)), 'pulse':local.get('SpritePulseEffector',{}),'arrow':arrow_go.get(go,{})}
 return result
