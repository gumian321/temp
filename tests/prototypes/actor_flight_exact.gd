extends "res://scripts/flight_batch.gd"
## Research variant: copy CanvasItem atlas half-texel clipping in the fragment.
var exact_shader:Shader
func setup(shared_materials:Dictionary):
	super.setup(shared_materials)
	var code=preload("res://shaders/attack_material.gdshader").code.replace("\r\n","\n")
	# Keep this research variant independent of the promoted equivalent block.
	var marker_begin=code.find("// ACTOR_SCREEN_TRANSFORM_BEGIN")
	var marker_end=code.find("// ACTOR_SCREEN_TRANSFORM_END")
	if marker_begin>=0 and marker_end>=0:
		code=code.left(marker_begin)+code.substr(marker_end+"// ACTOR_SCREEN_TRANSFORM_END".length())
	code=code.replace("void vertex(){","varying float actor_body;\nvarying vec4 actor_region;\nvoid vertex(){\n actor_body=0.0;vec2 actor_original_local=VERTEX;")
	code=code.replace("UV=region.xy+UV*region.zw;","UV=region.xy+UV*region.zw;\n actor_body=1.0;actor_region=vec4(region.xy+TEXTURE_PIXEL_SIZE*0.5,region.xy+region.zw-TEXTURE_PIXEL_SIZE*0.5);")
	code=code.replace("void fragment(){","void fragment(){\n if(actor_body>0.5){COLOR=texture(TEXTURE,clamp(UV,actor_region.xy,actor_region.zw));}")
	if OS.get_environment("RBPEW_PROTO_ACTOR_SCREEN")=="1":
		code=code.replace("render_mode unshaded;","render_mode unshaded, skip_vertex_transform;")
		code=code.replace("\n}\nfloat hash21",'''\n if(actor_body>0.5){
  int actor_slot=int(INSTANCE_CUSTOM.r);
  vec4 actor_pose=texelFetch(flight_data,ivec2(20,actor_slot),0);
  vec4 actor_basis=texelFetch(flight_data,ivec2(21,actor_slot),0);
  vec2 actor_origin=texelFetch(flight_data,ivec2(22,actor_slot),0).xy;
  vec2 actor_local=actor_original_local*actor_pose.xy;
  VERTEX=vec2(actor_basis.x*actor_local.x+actor_basis.z*actor_local.y,actor_basis.y*actor_local.x+actor_basis.w*actor_local.y)+actor_origin;
 }else{VERTEX=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
}
float hash21''')
	exact_shader=Shader.new();exact_shader.code=code
	for material in materials.values():material.shader=exact_shader

func enqueue(painter,state:Dictionary,trail:Dictionary,origin:Vector2,scale_factor:float,body:Dictionary={},kind:String="remnant")->bool:
	var result=super.enqueue(painter,state,trail,origin,scale_factor,body,kind)
	if result and not body.is_empty() and OS.get_environment("RBPEW_PROTO_ACTOR_SCREEN")=="1":
		var slot=int(entries[[int(state.visual_id),kind]].slot)
		var pose:Transform2D=body.screen_transform
		image_data.set_pixel(20,slot,Color(body.screen_extent.x,body.screen_extent.y,0,0))
		image_data.set_pixel(21,slot,Color(pose.x.x,pose.x.y,pose.y.x,pose.y.y))
		image_data.set_pixel(22,slot,Color(pose.origin.x,pose.origin.y,0,0));dirty=true
	return result
