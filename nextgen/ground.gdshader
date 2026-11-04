shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D soil_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D noise_map : filter_linear_mipmap, repeat_enable;
uniform float normal_strength = 0.35;
uniform bool isolate_color = false;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_pos.xz;
    float macro = texture(noise_map, p * 0.028).r;
    float micro = texture(noise_map, p * 0.3).r;
    vec3 soil = texture(soil_map, p * 0.18).rgb;
    float row = min(abs(p.y), min(abs(p.y - 4.08), abs(p.y + 4.08)));
    float edge = smoothstep(0.9, 1.2, row) * (1.0 - smoothstep(1.6, 2.25, row));
    float moss = clamp(edge * smoothstep(0.42, 0.72, macro + micro * 0.17) * 0.65, 0.0, 0.65);
    vec3 dirt = soil * mix(vec3(0.88,0.79,0.65), vec3(1.20,1.10,0.91), macro);
    ALBEDO = mix(dirt, soil * vec3(0.40,0.49,0.23), moss);
    if (isolate_color) { ALBEDO = vec3(0.25,0.23,0.18); }
    NORMAL_MAP = texture(soil_normal, p * 0.18).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    METALLIC = 0.0;
    ROUGHNESS = mix(0.77, 0.98, micro);
}
