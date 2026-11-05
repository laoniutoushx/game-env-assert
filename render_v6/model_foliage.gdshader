shader_type spatial;
render_mode cull_disabled,diffuse_burley,specular_schlick_ggx;
uniform sampler2D leaf_detail : hint_default_white,filter_linear_mipmap_anisotropic;
uniform sampler2D leaf_normal : hint_normal,filter_linear_mipmap_anisotropic;
uniform float wind_strength=0.0;
uniform float normal_strength=0.20;
uniform int backface_rule=0;
uniform bool surface_variation=true;
instance uniform vec4 plant_palette : source_color=vec4(1.0);
void vertex(){
 float h=max(VERTEX.y,0.0);
 VERTEX.x+=sin(TIME*1.2+VERTEX.y*2.0+MODEL_MATRIX[3].x)*min(h*h,1.0)*0.018*wind_strength;
}
void fragment(){
 if(!FRONT_FACING){
  if(backface_rule==0){NORMAL=-NORMAL;}
  else if(backface_rule==2){NORMAL=-NORMAL;TANGENT=-TANGENT;BINORMAL=-BINORMAL;}
  else if(backface_rule==3){NORMAL=-NORMAL;BINORMAL=-BINORMAL;}
 }
 float leaf=smoothstep(1.35,1.50,COLOR.g/max(COLOR.r,0.01));
 vec3 detail=texture(leaf_detail,UV).rgb;
 ALBEDO=COLOR.rgb*mix(vec3(1.0),detail*1.12,leaf)*plant_palette.rgb;
 NORMAL_MAP=texture(leaf_normal,UV).rgb;
 NORMAL_MAP_DEPTH=normal_strength*leaf;
 ROUGHNESS=mix(0.78,mix(0.68,0.82,smoothstep(0.82,0.94,detail.r)),leaf*float(surface_variation));
 SPECULAR=0.22;BACKLIGHT=ALBEDO*0.36*leaf;
}
