shader_type spatial;
render_mode cull_disabled;
void fragment() {
    vec2 p = UV * 16.0;
    float checker = mod(floor(p.x) + floor(p.y), 2.0);
    ALBEDO = mix(vec3(0.10,0.16,0.25),vec3(0.80,0.76,0.63),checker);
    ROUGHNESS = 0.8;
}
