shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D soil_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D noise_map : filter_linear_mipmap, repeat_enable;
uniform float normal_strength = 0.22;
uniform sampler2D forest_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float layered = 1.0;
uniform sampler2D road_distance_map : filter_linear, repeat_disable;
uniform int style_mode = 1;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float macro = texture(noise_map, p * 0.065).r;
	float micro = texture(noise_map, p * 0.3).r;
	vec2 rotated = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * p;
	vec3 soil = mix(texture(soil_map, p * 0.18).rgb, texture(soil_map, rotated * 0.143 + vec2(0.37, 0.71)).rgb, smoothstep(0.3, 0.7, macro));
	float row = texture(road_distance_map, (p + vec2(20.0, 20.0)) / 40.0).r * 3.0 + 0.7;
	float edge = smoothstep(0.72, 0.80, row) * (1.0 - smoothstep(1.00, 1.14, row));
	float moss = clamp((edge + smoothstep(0.48, 0.72, macro + micro * 0.15) * smoothstep(0.76, 1.3, row)) * 0.72, 0.0, 0.8);
	soil = mix(vec3(dot(soil, vec3(0.2126, 0.7152, 0.0722))), soil, style_mode == 2 ? 0.35 : 0.75);
	vec3 dirt = soil * mix(vec3(0.94, 0.95, 0.94), vec3(1.02, 1.02, 1.0), macro);
	ALBEDO = mix(dirt * vec3(0.92, 0.97, 0.90), soil * vec3(0.43, 0.61, 0.22), moss);
	float litter = smoothstep(0.94, 1.3, row) * (0.65 + 0.28 * smoothstep(0.25, 0.7, micro)) * layered;
	NORMAL_MAP = texture(soil_normal, p * 0.18).rgb;
	NORMAL_MAP = mix(NORMAL_MAP, texture(soil_normal, p * 1.6).rgb, 0.15);
	NORMAL_MAP_DEPTH = style_mode == 2 ? 0.04 : (style_mode == 1 ? normal_strength : normal_strength * 1.35);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.77, 0.98, micro);
	vec2 forest_dx = dFdx(p * 0.46), forest_dy = dFdy(p * 0.46);
	if (litter > 0.001 && style_mode != 2) {
		vec3 forest = textureGrad(forest_map, p * 0.46, forest_dx, forest_dy).rgb;
		ALBEDO = mix(ALBEDO, forest * vec3(0.90, 1.02, 0.92), litter);
		NORMAL_MAP = mix(NORMAL_MAP, textureGrad(forest_normal, p * 0.46, forest_dx, forest_dy).rgb, litter * 0.65);
		ROUGHNESS = mix(ROUGHNESS, textureGrad(forest_rough, p * 0.46, forest_dx, forest_dy).r, litter * 0.5);
	}
	ALBEDO *= 0.88;
}
