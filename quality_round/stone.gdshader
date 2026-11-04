shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec3 base_tint : source_color = vec3(0.95,0.97,1.0);
uniform float normal_depth = 0.65;
void fragment() {
    ALBEDO = texture(base_map,UV).rgb * base_tint;
    NORMAL_MAP = texture(normal_map,UV).rgb;
    NORMAL_MAP_DEPTH = normal_depth;
    ROUGHNESS = clamp(0.65 + texture(orm_map,UV).g * 0.35,0.65,0.98);
    METALLIC = 0.0;
    SPECULAR = 0.25;
}
