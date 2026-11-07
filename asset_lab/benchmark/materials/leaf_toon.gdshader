shader_type spatial;
render_mode cull_disabled;
#include "res://asset_lab/benchmark/materials/leaf_common.gdshaderinc"
void light() {
 float ndl=max(dot(NORMAL,LIGHT),0.0);
 float band=mix(0.10,0.52,smoothstep(0.15,0.24,ndl));
 band=mix(band,1.0,smoothstep(0.62,0.72,ndl));
 vec3 tint=mix(vec3(.72,.86,1.0),vec3(1.0),smoothstep(.15,.65,ndl));
 DIFFUSE_LIGHT+=tint*band*ATTENUATION*LIGHT_COLOR/PI;
}
