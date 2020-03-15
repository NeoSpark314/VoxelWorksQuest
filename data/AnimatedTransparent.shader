shader_type spatial;
render_mode cull_disabled, unshaded;

uniform int num_tiles = 8;
uniform float speed = 8.0;

uniform sampler2D albedo_texture;

void fragment() {
	
	float offset = float(int(TIME*speed) % num_tiles);
	float scale_y = 1.0 / float(num_tiles);
	
	vec4 t = texture(albedo_texture, (UV + vec2(0, offset)) * vec2(1.0, scale_y));
	ALBEDO = t.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR = 0.5;
}
