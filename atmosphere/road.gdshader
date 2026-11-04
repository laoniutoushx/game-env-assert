shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D base_map : source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D rough_map : hint_default_white,filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color=vec3(0.86,0.88,0.85);
uniform vec4 wet_centers[4];
uniform sampler2D rune_map : hint_default_black,filter_linear_mipmap_anisotropic;
uniform float rune_enabled=0.0;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    float wet=0.0;
    for(int i=0;i<4;i++){
        float r=length((world_pos.xz-wet_centers[i].xy)/vec2(1.0,1.15));
        wet=max(wet,(1.0-smoothstep(0.25,0.65,r))*wet_centers[i].z);
    }
    ALBEDO=texture(base_map,UV).rgb*tint*COLOR.rgb*mix(1.0,0.66,wet);
    NORMAL_MAP=texture(normal_map,UV).rgb;
    NORMAL_MAP_DEPTH=0.32;
    if(rune_enabled>0.5){
        float h=texture(rune_map,UV).r;
        vec2 ray=vec2(dot(VIEW,TANGENT),dot(VIEW,BINORMAL))/max(dot(VIEW,NORMAL),0.25);
        vec2 uv=UV-ray*h*0.006;
        h=texture(rune_map,uv).r;
        float e=1.0/2048.0;
        vec2 slope=vec2(texture(rune_map,uv-vec2(e,0)).r-texture(rune_map,uv+vec2(e,0)).r,texture(rune_map,uv-vec2(0,e)).r-texture(rune_map,uv+vec2(0,e)).r);
        NORMAL_MAP=normalize((NORMAL_MAP*2.0-1.0)+vec3(slope*0.65,0))*0.5+0.5;
        ALBEDO*=1.0-h*0.38;
    }
    ROUGHNESS=mix(clamp(texture(rough_map,UV).r*0.95,0.7,0.95),0.18,wet);
    SPECULAR=mix(0.28,0.5,wet);
}
