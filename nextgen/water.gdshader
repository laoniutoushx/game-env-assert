shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
void fragment() {
    float interior = smoothstep(0.0,0.4,COLOR.r);
    ALBEDO = mix(vec3(0.13,0.14,0.13),vec3(0.12,0.18,0.21),interior);
    METALLIC = 0.0;
    ROUGHNESS = mix(0.48,0.08,interior);
    SPECULAR = 0.7;
    NORMAL_MAP = normalize(vec3(sin(UV.x*43.0+UV.y*8.0)*0.025,cos(UV.y*51.0)*0.025,1.0))*0.5+0.5;
    NORMAL_MAP_DEPTH = 0.35;
}
