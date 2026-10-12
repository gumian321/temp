extends CanvasLayer
var rectangle:ColorRect
var shader_material:ShaderMaterial
func setup(textures:Array):
 layer=-20
 rectangle=ColorRect.new();rectangle.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(rectangle)
 shader_material=ShaderMaterial.new();shader_material.shader=load('res://shaders/background_layers.gdshader')
 for i in textures.size():shader_material.set_shader_parameter('layer'+str(i),textures[i])
 rectangle.material=shader_material
func configure(camera:Vector2,color:Color,extent:Vector2):
 rectangle.size=extent
 shader_material.set_shader_parameter('viewport_size',extent)
 shader_material.set_shader_parameter('camera_world',camera)
 shader_material.set_shader_parameter('base_color',color)
