shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D leaf_detail : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform float wind_strength = 0.0;
instance uniform vec4 plant_palette : source_color = vec4(1.0);
void vertex() {
 float h=max(VERTEX.y,0.0);
 VERTEX.x += sin(TIME*1.2+VERTEX.y*2.0+MODEL_MATRIX[3].x)*min(h*h,1.0)*0.018*wind_strength;
}
void fragment() {
 if (!FRONT_FACING) NORMAL=-NORMAL;
 float leaf=step(COLOR.r*1.15,COLOR.g);
 ALBEDO=COLOR.rgb*mix(vec3(1.0),texture(leaf_detail,UV).rgb*1.12,leaf)*plant_palette.rgb;
 ROUGHNESS=0.78; SPECULAR=0.22;
 BACKLIGHT=ALBEDO*0.22*leaf;
}
