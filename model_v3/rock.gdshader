shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
float noise3(vec3 p){
 vec3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 float n=dot(i,vec3(1.0,57.0,113.0));
 vec4 a=fract(sin(vec4(n,n+1.0,n+57.0,n+58.0))*43758.5453);
 vec4 b=fract(sin(vec4(n+113.0,n+114.0,n+170.0,n+171.0))*43758.5453);
 return mix(mix(mix(a.x,a.y,f.x),mix(a.z,a.w,f.x),f.y),mix(mix(b.x,b.y,f.x),mix(b.z,b.w,f.x),f.y),f.z);
}
void fragment(){
 float variation=0.88+0.16*noise3(local_position*9.0)+0.04*noise3(local_position*85.0);
 ALBEDO=COLOR.rgb*vec3(0.63,0.65,0.67)*variation;
 ROUGHNESS=0.86;SPECULAR=0.24;
}
