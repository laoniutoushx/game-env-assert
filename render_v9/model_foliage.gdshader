shader_type spatial;
render_mode cull_disabled,diffuse_burley,specular_schlick_ggx;
uniform sampler2D leaf_detail : hint_default_white,filter_linear_mipmap_anisotropic;
uniform sampler2D leaf_normal : hint_normal,filter_linear_mipmap_anisotropic;
uniform float wind_strength=0.0;
uniform float normal_strength=0.20;
uniform int backface_rule=0;
uniform bool surface_variation=true;
uniform bool surface_features=false;
uniform bool normal_enabled=true;
uniform float leaf_roughness_floor=0.60;
uniform float leaf_backlight_gain=1.0;
uniform float leaf_specular_scale=1.0;
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
 if(surface_features){NORMAL_MAP_DEPTH*=1.0-smoothstep(12.0,28.0,length(VERTEX));}
 if(!normal_enabled){NORMAL_MAP_DEPTH=0.0;}
 ROUGHNESS=mix(0.78,mix(0.68,0.82,smoothstep(0.82,0.94,detail.r)),leaf*float(surface_variation));
 if(surface_features){
  vec3 dx=dFdx(NORMAL_MAP)*NORMAL_MAP_DEPTH;
  vec3 dy=dFdy(NORMAL_MAP)*NORMAL_MAP_DEPTH;
  ROUGHNESS=max(ROUGHNESS,mix(0.0,clamp(leaf_roughness_floor+sqrt(max(dot(dx,dx),dot(dy,dy)))*0.7,leaf_roughness_floor,0.95),leaf));
 }
 SPECULAR=0.22*mix(1.0,leaf_specular_scale,leaf);BACKLIGHT=ALBEDO*0.36*leaf*leaf_backlight_gain;
}
