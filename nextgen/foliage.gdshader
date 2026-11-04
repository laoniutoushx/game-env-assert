shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D ao_map : hint_default_white, filter_linear_mipmap;
uniform bool has_ao = false;
uniform bool coverage_enabled = true;
uniform float normal_strength = 1.0;
uniform vec3 species_tint : source_color = vec3(1.0);
void fragment() {
    vec4 sample_base = texture(base_map, UV);
    vec3 base = sample_base.rgb;
    float leaf = smoothstep(0.005, 0.08, base.g - base.r);
    ALBEDO = base * species_tint;
    NORMAL_MAP = texture(normal_map, UV).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    float rough = clamp(texture(orm_map, UV).g * 1.1, 0.48, 0.9);
    ROUGHNESS = mix(max(rough,0.8),rough,leaf);
    METALLIC = 0.0;
    SPECULAR = mix(0.15,0.25,leaf);
    BACKLIGHT = base * leaf * 0.08;
    AO = has_ao ? mix(1.0, texture(ao_map, UV).r, 0.45) : 1.0;
    AO_LIGHT_AFFECT = 0.35;
    ALPHA = sample_base.a;
    ALPHA_SCISSOR_THRESHOLD = 0.45;
    ALPHA_ANTIALIASING_EDGE = coverage_enabled ? 0.3 : 0.0;
    ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(base_map, 0));
}
