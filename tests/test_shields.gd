extends SceneTree
var checks=[]
func check(value:bool,name:String):checks.append({'name':name,'passed':value})
func _initialize():
 var db=load('res://scripts/source_db.gd').new();var p=load('res://scripts/centipede.gd').new(db);var b=load('res://scripts/combat.gd').new(db,p)
 var shield=db.named('Core_Shield');p.add_piece(shield.id,Vector2i(-1,0));var part=p.parts[1]
 check(part.shield==shield.maxShieldHealth,'New shield begins charged')
 p.add_piece(db.named('Core_Chip_Mammoth').id,Vector2i(-2,0))
 check(p.chips(1).get(5,0)==1 and b.shield_range(1)>shield.ShieldRange*48,'Mammoth chip enlarges shield range')
 var before=p.parts[0].hp;b.hurt_player(0,200,999)
 check(p.parts[0].hp==before and part.shield==0 and part.shield_broken,'Breaking shield absorbs triggering shot')
 var delay=shield.maxShieldHealth/2/shield.shieldRechargeRate
 check(is_equal_approx(part.shield_delay,delay),'Destroyed recovery delay uses half capacity divided by rate')
 b.step(delay-0.1,Vector2.RIGHT,false)
 check(part.shield==0,'Broken shield remains unavailable before recovery')
 b.step(0.11,Vector2.RIGHT,false)
 check(is_equal_approx(part.shield,shield.maxShieldHealth/2),'Broken shield reappears at half capacity')
 part.stun=1;b.hurt_player(0,7,10)
 check(p.parts[0].hp==before-7,'Stunned shield does not intercept hull damage')
 var report={'checks':checks,'passed':checks.all(func(c):return c.passed)}
 FileAccess.open('res://artifacts/shield-test-report.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print(JSON.stringify(report));quit(0 if report.passed else 1)
