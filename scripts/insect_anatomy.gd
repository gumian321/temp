extends RefCounted
## UV cutouts in the original artwork. Only the torso enters the elastic mesh.
## Coordinates are fractions of the full PNG, independent of import resolution.
static var mesh_cache:Dictionary={}

static func polygon(points:Array)->PackedVector2Array:
	var result=PackedVector2Array()
	for p in points:result.append(Vector2(p[0],p[1]))
	return result

static func rect(x:float,y:float,w:float,h:float)->PackedVector2Array:
	return polygon([[x,y],[x+w,y],[x+w,y+h],[x,y+h]])

static func mirror(points:PackedVector2Array)->PackedVector2Array:
	var result=PackedVector2Array()
	for p in points:result.append(Vector2(1-p.x,p.y))
	result.reverse()
	return result

static func torso(left:Array)->PackedVector2Array:
	var result=polygon(left)
	for i in range(left.size()-2,0,-1):result.append(Vector2(1-left[i][0],left[i][1]))
	return result

static func leg(hip:Vector2,knee:Vector2,foot:Vector2,region:PackedVector2Array)->Dictionary:
	return {"hip":hip,"knee":knee,"foot":foot,"region":region,"shift":Vector2.ZERO}

static func definition(species:String)->Dictionary:
	var body:PackedVector2Array
	var legs:Array=[]
	var antenna:PackedVector2Array
	var antenna_root:Vector2
	var wings:Array=[]
	match species:
		"grub":
			body=torso([[.5,.083],[.426,.086],[.37,.119],[.338,.192],[.300,.221],[.303,.269],[.269,.302],[.272,.372],[.241,.402],[.236,.469],[.215,.554],[.22,.725],[.24,.866],[.30,.970],[.43,.999],[.5,1.0]])
			legs=[leg(Vector2(.278,.31),Vector2(.211,.298),Vector2(.164,.312),rect(.135,.267,.15,.073)),leg(Vector2(.247,.462),Vector2(.174,.453),Vector2(.121,.472),rect(.085,.415,.17,.088))]
			var rear=legs[1].duplicate(true);rear.shift=Vector2(.002,.18);legs.append(rear)
			antenna=rect(.19,0,.257,.206);antenna_root=Vector2(.442,.092)
		"beetle":
			body=torso([[.5,.193],[.443,.20],[.395,.218],[.349,.248],[.342,.299],[.321,.322],[.279,.364],[.271,.419],[.255,.465],[.228,.522],[.21,.631],[.224,.705],[.229,.746],[.249,.774],[.276,.738],[.285,.785],[.303,.817],[.4,.91],[.5,.929]])
			legs=[leg(Vector2(.291,.397),Vector2(.204,.391),Vector2(.158,.269),polygon([[.12,.212],[.206,.213],[.286,.35],[.317,.354],[.311,.46],[.208,.46],[.115,.342]])),leg(Vector2(.259,.517),Vector2(.167,.53),Vector2(.058,.678),rect(0,.478,.28,.275)),leg(Vector2(.247,.71),Vector2(.177,.729),Vector2(.219,.877),rect(.13,.663,.174,.337))]
			antenna=rect(.265,0,.21,.244);antenna_root=Vector2(.411,.239)
		"moth":
			body=torso([[.5,.131],[.459,.152],[.416,.181],[.400,.228],[.377,.256],[.385,.346],[.39,.42],[.368,.505],[.368,.671],[.373,.77],[.399,.852],[.441,.924],[.5,.978]])
			legs=[leg(Vector2(.405,.267),Vector2(.352,.222),Vector2(.28,.172),rect(.261,.148,.152,.126)),leg(Vector2(.367,.628),Vector2(.34,.778),Vector2(.318,.925),rect(.292,.578,.092,.422))]
			var middle=legs[0].duplicate(true);middle.shift=Vector2(-.006,.20);legs.insert(1,middle)
			antenna=polygon([[.297,0],[.449,0],[.493,.166],[.48,.186],[.424,.147],[.338,.098],[.297,.066]]);antenna_root=Vector2(.475,.16)
			wings=[{"root":Vector2(.401,.284),"region":polygon([[.410,.247],[.35,.255],[.259,.327],[.116,.431],[.03,.54],[0,.65],[0,.744],[.045,.795],[.057,.87],[.139,.925],[.237,.877],[.332,.711],[.361,.564],[.379,.433]])}]
		"sac":
			body=torso([[.5,.211],[.438,.217],[.411,.237],[.415,.278],[.374,.306],[.366,.354],[.378,.385],[.312,.42],[.292,.476],[.264,.534],[.234,.598],[.20,.674],[.234,.784],[.29,.867],[.385,.94],[.464,.964],[.5,.985]])
			legs=[leg(Vector2(.382,.371),Vector2(.292,.345),Vector2(.235,.286),rect(.174,.267,.231,.139)),leg(Vector2(.288,.50),Vector2(.217,.473),Vector2(.119,.560),rect(.075,.437,.244,.17)),leg(Vector2(.227,.7),Vector2(.169,.72),Vector2(.168,.843),rect(.129,.665,.139,.228))]
			antenna=rect(.045,.005,.425,.235);antenna_root=Vector2(.45,.227)
		"mantis":
			body=torso([[.5,.099],[.454,.111],[.429,.106],[.408,.14],[.439,.188],[.419,.178],[.444,.21],[.429,.24],[.45,.254],[.432,.289],[.421,.338],[.396,.435],[.432,.419],[.394,.451],[.365,.509],[.348,.606],[.323,.672],[.337,.842],[.397,.941],[.5,.989]])
			# Foreleg: shoulder -> elbow -> wrist -> rigid sickle. Three true joints.
			legs=[{"hip":Vector2(.445,.275),"knee":Vector2(.310,.438),"wrist":Vector2(.348,.208),"foot":Vector2(.148,.543),"shift":Vector2.ZERO,"parts":[polygon([[.391,.247],[.455,.263],[.421,.336],[.389,.393],[.329,.459],[.28,.454],[.281,.416],[.329,.357],[.358,.278]]),polygon([[.286,.44],[.264,.405],[.291,.326],[.325,.23],[.326,.199],[.369,.199],[.388,.231],[.362,.33],[.362,.413],[.329,.443]]),polygon([[.066,.566],[.061,.414],[.115,.307],[.225,.204],[.287,.167],[.333,.16],[.377,.181],[.368,.243],[.298,.304],[.246,.393],[.208,.479],[.173,.555]])]},leg(Vector2(.347,.556),Vector2(.221,.509),Vector2(.172,.612),polygon([[.202,.488],[.25,.488],[.374,.532],[.369,.578],[.25,.57],[.196,.638],[.137,.638],[.139,.594],[.181,.55]])),leg(Vector2(.335,.668),Vector2(.219,.681),Vector2(.20,.786),rect(.16,.634,.215,.187))]
			antenna=rect(.31,0,.168,.15);antenna_root=Vector2(.468,.129)
		"queen":
			body=torso([[.5,.045],[.437,.10],[.433,.133],[.39,.147],[.39,.206],[.416,.213],[.379,.228],[.359,.256],[.325,.279],[.315,.33],[.287,.381],[.244,.407],[.212,.447],[.186,.474],[.135,.53],[.083,.613],[.095,.791],[.159,.888],[.251,.959],[.39,.987],[.5,1.0]])
			legs=[leg(Vector2(.351,.269),Vector2(.277,.245),Vector2(.227,.235),rect(.19,.173,.195,.131)),leg(Vector2(.311,.364),Vector2(.193,.344),Vector2(.137,.432),rect(.095,.299,.244,.177))]
			var rear=legs[1].duplicate(true);rear.shift=Vector2(-.09,.23);legs.append(rear)
			antenna=rect(.225,0,.234,.141);antenna_root=Vector2(.445,.141)
	return {"body":body,"legs":legs,"antenna":antenna,"antenna_root":antenna_root,"wings":wings}

static func body_geometry(species:String)->Dictionary:
	if mesh_cache.has(species):return mesh_cache[species]
	var border:PackedVector2Array=definition(species).body
	var vertices=PackedVector2Array();var triangles:Array[PackedInt32Array]=[]
	# Clip the lattice to the torso silhouette, excluding all legs, wings and feelers.
	for y in range(24):
		for x in range(16):
			for patch in Geometry2D.intersect_polygons(border,rect(x/16.0,y/24.0,1.0/16,1.0/24)):
				var ids=Geometry2D.triangulate_polygon(patch)
				var start=vertices.size();vertices.append_array(patch)
				for i in range(0,ids.size(),3):triangles.append(PackedInt32Array([start+ids[i],start+ids[i+1],start+ids[i+2]]))
	mesh_cache[species]={"vertices":vertices,"triangles":triangles}
	return mesh_cache[species]

static func split_leg(region:PackedVector2Array,knee:Vector2,foot:Vector2)->Array:
	var axis=(foot-knee).normalized();var across=axis.orthogonal()*3
	# A small overlap at the joint hides the seam as the two rigid pieces rotate.
	var upper=PackedVector2Array([knee+axis*.012-across,knee+axis*.012+across,knee-axis*3+across,knee-axis*3-across])
	var lower=PackedVector2Array([knee-axis*.012-across,knee-axis*.012+across,knee+axis*3+across,knee+axis*3-across])
	return [Geometry2D.intersect_polygons(region,upper),Geometry2D.intersect_polygons(region,lower)]
