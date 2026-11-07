shader_type spatial;
render_mode cull_disabled;
#include "res://asset_lab/benchmark/materials/leaf_common.gdshaderinc"
void light() {
 float ndl=max(dot(NORMAL,LIGHT),0.0);
 float level=mix(0.12,0.52,smoothstep(0.12,0.22,ndl));
 level=mix(level,1.0,smoothstep(0.60,0.70,ndl));
 vec3 shade_tint=mix(vec3(0.55,0.72,1.0),vec3(1.0),smoothstep(0.15,0.65,ndl));
 DIFFUSE_LIGHT+=shade_tint*(level+max(dot(-NORMAL,LIGHT),0.0)*0.05)*ATTENUATION*LIGHT_COLOR/PI;
}
