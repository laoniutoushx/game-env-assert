shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D ao_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform bool has_ao = false;
uniform bool has_orm = false;
uniform bool orm_has_ao = false;
uniform float roughness_factor = 1.0;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform bool coverage_enabled = true;
uniform float normal_strength = 1.0;
uniform float wind_strength = 0.0;
uniform float leaf_surface = 1.0;
uniform vec3 species_tint : source_color = vec3(1.0);
uniform vec3 warm_leaf_tint = vec3(1.0);
void vertex() {
    float root_lock = smoothstep(0.02,0.45,VERTEX.y);
    float phase = dot(MODEL_MATRIX[3].xz,vec2(0.71,0.37));
    VERTEX.x += sin(TIME*1.1+phase+VERTEX.y*1.3)*root_lock*wind_strength*leaf_surface;
    VERTEX.z += cos(TIME*0.83+phase+VERTEX.x)*root_lock*wind_strength*0.5*leaf_surface;
}
void fragment() {
    if(!FRONT_FACING){NORMAL=-NORMAL;}
    vec4 base = texture(base_map,UV)*source_tint;
    if(base.a<0.001){discard;}
    vec3 orm = texture(orm_map,UV).rgb;
    float leaf = smoothstep(0.005,0.07,base.g-base.r)*leaf_surface;
    ALBEDO = base.rgb*species_tint;
    NORMAL_MAP = texture(normal_map,UV).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = clamp((has_orm?orm.g:1.0)*roughness_factor,0.30,0.95);
    METALLIC = 0.0;
    SPECULAR = mix(0.28,0.38,leaf);
    BACKLIGHT = base.rgb*leaf*0.32;
    float source_ao = has_ao?texture(ao_map,UV).r:(orm_has_ao?orm.r:1.0);
    AO = mix(1.0,source_ao,0.65);
    AO_LIGHT_AFFECT = 0.15;
    ALPHA = base.a;
    ALPHA_SCISSOR_THRESHOLD = 0.45;
    ALPHA_ANTIALIASING_EDGE = coverage_enabled?0.3:0.0;
    ALPHA_TEXTURE_COORDINATE = UV*vec2(textureSize(base_map,0));
}
