uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_strength : hint_range(0.0,1.0) = 0.22;
uniform float roughness : hint_range(0.0,1.0) = 0.8;
uniform float variation : hint_range(0.0,0.3) = 0.08;
uniform float wind_strength : hint_range(0.0,1.0) = 0.0;
uniform vec3 clean_tint : source_color = vec3(0.42,0.62,0.18);
uniform float texture_weight : hint_range(0.0,1.0) = 1.0;
void vertex() {
 float sway=sin(TIME*1.3+VERTEX.x*1.1+VERTEX.z*0.7)*wind_strength*COLOR.b*0.04;
 VERTEX.x+=sway;
}
void fragment() {
 vec3 color=texture(base_map,UV).rgb;
 ALBEDO=mix(clean_tint,color,texture_weight)*(1.0+(COLOR.g-0.5)*variation);
 if(!FRONT_FACING) NORMAL=-NORMAL;
 NORMAL_MAP=texture(normal_map,UV).rgb;
 NORMAL_MAP_DEPTH=FRONT_FACING?normal_strength:0.0;
 METALLIC=0.0;
 ROUGHNESS=roughness;
 SPECULAR=0.22;
 AO=mix(1.0,COLOR.r,0.25);
 BACKLIGHT=ALBEDO*0.12;
}
