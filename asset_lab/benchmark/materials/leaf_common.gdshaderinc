uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_strength : hint_range(0.0,1.0) = 0.18;
uniform float roughness : hint_range(0.0,1.0) = 0.78;
uniform float variation : hint_range(0.0,0.5) = 0.14;
uniform float wind_strength : hint_range(0.0,1.0) = 0.0;
uniform vec3 clean_tint : source_color = vec3(0.42,0.62,0.24);
uniform float texture_weight : hint_range(0.0,1.0) = 1.0;
uniform float ao_strength : hint_range(0.0,1.0) = 0.45;
uniform int style_mode = 1;
void vertex() {
 float phase=TIME*1.45+VERTEX.x*1.2+VERTEX.z*.85;
 float sway=sin(phase)*wind_strength*COLOR.b*.025;
 VERTEX.x+=sway;
 VERTEX.z+=cos(phase*.8)*sway*.5;
}
void fragment() {
 vec3 base=texture(base_map,UV).rgb;
 ALBEDO=mix(clean_tint,base,texture_weight)*(1.0+(COLOR.g-.5)*variation);
 // One indirect occlusion term from real visibility samples. Do not bake it into albedo.
 AO=mix(1.0,clamp(COLOR.r,0.0,1.0),ao_strength);
 AO_LIGHT_AFFECT=0.0;
 METALLIC=0.0;
 ROUGHNESS=roughness;
 SPECULAR=style_mode==2?0.06:0.30;
 BACKLIGHT=ALBEDO*(style_mode==0?0.14:0.10);
 if(!FRONT_FACING) NORMAL=-NORMAL;
 NORMAL_MAP=texture(normal_map,UV).rgb;
 NORMAL_MAP_DEPTH=FRONT_FACING?normal_strength:normal_strength*.2;
}
