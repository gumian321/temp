shader_type canvas_item;
render_mode unshaded;
uniform sampler2D ground_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 camera_world;
uniform vec2 viewport_size = vec2(1440.0, 900.0);
uniform float camera_zoom = 1.0;
uniform vec2 screen_offset;
uniform float terrain_strength = 1.0;
void fragment() {
	vec2 pixels = UV * viewport_size;
	vec2 world = (pixels - viewport_size * 0.5 - screen_offset) / max(camera_zoom, 0.01) + camera_world;
	// Blend opposite borders through an interior sample, avoiding mirrored motifs.
	vec2 tile = fract(world / 1700.0 + vec2(0.32,0.37));
	vec2 alternate = fract(tile + 0.5);
	vec2 blend = smoothstep(vec2(0.0),vec2(0.07),min(tile,1.0-tile));
	vec3 first = mix(texture(ground_texture,vec2(alternate.x,tile.y)).rgb,texture(ground_texture,tile).rgb,blend.x);
	vec3 second = mix(texture(ground_texture,alternate).rgb,texture(ground_texture,vec2(tile.x,alternate.y)).rgb,blend.x);
	vec3 ground = mix(second,first,blend.y);
	ground = mix(vec3(0.25),ground,0.80);
	COLOR = vec4(mix(vec3(0.055), ground, terrain_strength), 1.0);
}
