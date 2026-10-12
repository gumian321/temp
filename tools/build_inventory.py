import json,re,csv
from pathlib import Path
R=Path(__file__).resolve().parents[1]
m=json.loads((R/'data/source_manifest.json').read_text())
groups=[('菜单/设置/输入','Menu|Intro|Option|Input|Language|Localization|Resolution|ScreenMode|Control|UIBack|ScenesManager|GameVersion|VersionUI'),('自由建造/主体/蜈蚣','Build|Core|PlayerManager|PlayerMovement|Engine|Wall|Decoration'),('武器/弹道/雷达','Projectile|Turret|Radar|Damage|Mine|Explosion|Blade|BlackHole|Shield'),('芯片','Chip'),('无人机','Drone'),('敌人AI/Boss/地图','^AI|Fleet|Trader|Station|Asteroid|Map|Spawner|Patrol|Swarming'),('任务/计时/热量','Mission|ModeManager|GameHeat|GameTime|BossTimer'),('奖励/经济/研究/评分','Reward|Economy|Upgrade|Rating|Scrap|Score'),('存档/平台','Save|Steam|Achievement|Analytics|FBPP'),('音画/UI/辅助','.*')]
rows=[]
for s in m['scripts']:
 name=Path(s['path']).stem
 group=next(g for g,p in groups if re.search(p,name))
 rows.append([group,name,s['path'],str(s['lines']),'; '.join(s['methods']),'源代码存在','迁移未完成','未验证'])
with (R/'docs/source_feature_matrix.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['系统','类','Unity源文件','行数','方法','源状态','Godot状态','验证']);w.writerows(rows)
text='# 功能对照表\n\n本表以实际源代码为依据；完整逐类方法清单见 source_feature_matrix.csv。导入数据不能替代行为验收。\n\n| 系统 | 必须覆盖的功能 | 当前状态 |\n|---|---|---|\n'
features=[('菜单和设置','Intro/MainMenu/Game 三场景流程；任务/难度选择、实验室、暂停、重开、结算；音量、分辨率、语言、控制重绑定、跳过Boss镜头'),('自由建造','二维自由布局、邻接吸附、连接合法性、上限/边界、队列、移动、交换、复制、加墙、损毁重连'),('主角变化','头部带路、按弧长跟随、各身体节可装炮；原自由建造仍可用'),('武器','原全部HQ与模块炮；加特林、霰弹、炮弹、狙击、火焰、火箭、核弹、EMP、音波、特斯拉、黑洞、地雷；各弹道与碰撞'),('芯片','Shrapnel/Exploding/Piercing/Chain/Mammoth/HQControl 六类；邻接范围、兼容性、叠加规则'),('无人机/支援','攻击、工程、拾荒无人机；盾、维修、燃料、隐形、墙与升级'),('敌人AI','巡逻、追随、蜂群、守卫；独立行为、武器、热量难度、波次、舰队、跃迁'),('Boss','小/中/终局Boss组合部件、血量、加速、波次暂停和任务回调'),('地图','节点、陨石、容器、矿场、空间站、生成器、事件、地图与方向箭头'),('任务','生存、无尽、赏金猎人、守护天使、空间站猎人/守护者，各三难度，原配置目标与结束判定'),('奖励','稀有度、奖励包、重抽/价格、选择资格、互斥、诅咒、HQ替换、建造/升级/百分比奖励'),('研究','前置树、成本、逐级解锁、启用/禁用、元货币与持久化'),('存档','新档55元货币、设置、解锁、研究、成绩；损坏档恢复；原存档语义'),('评分/成就','原评分项、任务加成、元货币结算、成就；Steam在线部分单独说明源限制'),('视听/本地化','使用来源素材和文本、音效/音乐、伤害反馈、镜头、教学提示、游戏手柄')]
for g,d in features:text+=f'| {g} | {d} | 迁移未完成 |\n'
(R/'docs/FEATURE_PARITY.md').write_text(text)
print('Inventory rows',len(rows))
