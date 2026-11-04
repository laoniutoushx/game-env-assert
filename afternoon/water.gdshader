shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;
uniform sampler2D screen_image : hint_screen_texture,filter_linear_mipmap;
uniform samplerCube water_reflection : source_color,filter_linear_mipmap;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    vec2 wave=vec2(sin(world_pos.x*24.0+TIME*0.35),cos(world_pos.z*29.0+TIME*0.27))*0.0004;
    vec3 bottom=textureLod(screen_image,SCREEN_UV+wave,0.0).rgb;
    ALBEDO=vec3(0.015,0.036,0.025);
    EMISSION=bottom*vec3(0.67,0.76,0.70);
    ROUGHNESS=0.075;METALLIC=0.0;SPECULAR=0.5;
    NORMAL_MAP=normalize(vec3(wave*28.0,1.0))*0.5+0.5;
    vec3 eye=normalize(INV_VIEW_MATRIX[3].xyz-world_pos);
    vec3 reflected=reflect(-eye,vec3(0.0,1.0,0.0));
    RADIANCE=vec4(textureLod(water_reflection,reflected,0.7).rgb,0.8);
    ALPHA=(1.0-smoothstep(0.86,1.0,length((UV-0.5)*2.0)))*0.92;
}
