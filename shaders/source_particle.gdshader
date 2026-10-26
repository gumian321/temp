shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform bool single_channel = false;
uniform bool blue_ink = true;
uniform bool additive_source = false;
uniform bool burst_flash = false;
uniform vec2 frames = vec2(1.0);
uniform float length_scale = 1.0;
uniform float velocity_scale = 0.0;
uniform float speed = 0.0;
uniform float size = 1.0;
uniform float decay = 0.0;
uniform float lifetime = 1.0;
varying vec4 particle_color;
void vertex() {
	particle_color = COLOR;
	// Match CanvasItemMaterial's particle frame layout, including stretched sprites.
	float frame = mod(floor(INSTANCE_CUSTOM.z * frames.x * frames.y), frames.x * frames.y);
	UV = (UV + vec2(mod(frame, frames.x), floor(frame / frames.x))) / frames;
	VERTEX /= frames;
	float velocity = abs(speed) * exp(-decay * INSTANCE_CUSTOM.y * lifetime);
	VERTEX.y *= max(0.001, length_scale + velocity_scale * velocity / max(0.0001, size));
}
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	// Cartoon FX's red channel is the coverage mask, not red paint on a black quad.
	float mask = sample_color.a * (single_channel ? sample_color.r : 1.0);
	vec3 pigment = single_channel ? vec3(1.0) : sample_color.rgb;
	if (additive_source && !single_channel) { mask *= max(pigment.r, max(pigment.g, pigment.b)); }
	if (blue_ink) {
		float density = dot(pigment, vec3(0.299, 0.587, 0.114));
		vec3 paint = mix(vec3(0.24, 0.43, 0.69), vec3(0.055, 0.16, 0.34), density);
		if (burst_flash) {
			float core = 1.0 - smoothstep(0.13, 0.29, length(UV - vec2(0.5)));
			paint = mix(paint, vec3(0.965, 0.949, 0.906), core * 0.15);
		}
		float wash = additive_source && !single_channel ? 0.25 : 1.0;
		COLOR = vec4(paint, mask * particle_color.a * wash);
	} else {
		COLOR = vec4(pigment * particle_color.rgb, mask * particle_color.a);
	}
}
