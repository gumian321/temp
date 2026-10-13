extends CanvasLayer
var rectangle:ColorRect
var shader_material:ShaderMaterial
func setup(_textures:Array):
 layer=-20
 rectangle=ColorRect.new();rectangle.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(rectangle)
 shader_material=ShaderMaterial.new();shader_material.shader=load('res://shaders/ink_paper.gdshader')
 rectangle.material=shader_material
func configure(camera:Vector2,_color:Color,extent:Vector2,zoom:float=1.0,screen_offset:Vector2=Vector2.ZERO,terrain:bool=true):
 rectangle.size=extent
 shader_material.set_shader_parameter('viewport_size',extent)
 shader_material.set_shader_parameter('camera_world',camera)
 shader_material.set_shader_parameter('camera_zoom',zoom)
 shader_material.set_shader_parameter('screen_offset',screen_offset)
 shader_material.set_shader_parameter('terrain_strength',1.0 if terrain else 0.0)
