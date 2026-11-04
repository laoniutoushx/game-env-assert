shader_type spatial;
render_mode cull_disabled,diffuse_burley;
uniform float wind_strength=0.0;
void vertex(){
    float lock_root=smoothstep(0.015,0.25,VERTEX.y);
    float phase=dot(MODEL_MATRIX[3].xz,vec2(0.7,0.31));
    VERTEX.x+=sin(TIME*1.1+phase+VERTEX.y*2.0)*lock_root*wind_strength;
    VERTEX.z+=cos(TIME*0.8+phase)*lock_root*wind_strength*0.5;
}
void fragment(){ALBEDO=COLOR.rgb;ROUGHNESS=0.82;SPECULAR=0.18;BACKLIGHT=COLOR.rgb*0.06;}
