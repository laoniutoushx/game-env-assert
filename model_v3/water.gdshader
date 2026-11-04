shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx,alpha_to_coverage;
uniform sampler2D stone_map : source_color,filter_linear_mipmap_anisotropic;
uniform float seed=0.0;
uniform float wave_speed=1.0;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 p=(UV-0.5)*2.0;
    float edge=1.0-smoothstep(0.86,0.99,length(p));
    vec3 bottom=texture(stone_map,UV2).rgb;
    float luma=dot(bottom,vec3(0.2126,0.7152,0.0722));
    bottom=mix(vec3(luma),bottom,0.45)*vec3(0.86,0.91,0.96);
    ALBEDO=mix(vec3(0.025,0.065,0.075),bottom,0.72);
    ROUGHNESS=mix(0.24,0.12,smoothstep(0.0,0.5,edge));
    METALLIC=0.0;SPECULAR=0.35;
    vec2 wave=vec2(sin(world_pos.x*24.0+TIME*0.35*wave_speed),cos(world_pos.z*29.0+TIME*0.27*wave_speed))*0.012;
    NORMAL_MAP=normalize(vec3(wave,1.0))*0.5+0.5;NORMAL_MAP_DEPTH=0.4;
    ALPHA=edge;ALPHA_SCISSOR_THRESHOLD=0.45;ALPHA_ANTIALIASING_EDGE=0.3;
    ALPHA_TEXTURE_COORDINATE=UV*512.0;
}

