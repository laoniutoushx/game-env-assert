shader_type fog;
uniform float density = 0.007;
void fog(){
    float height_fade=1.0-smoothstep(0.25,1.0,UVW.y);
    float edge=1.0-smoothstep(0.32,0.5,max(abs(UVW.x-0.5),abs(UVW.z-0.5)));
    DENSITY=density*height_fade*edge;
    ALBEDO=vec3(0.96,0.94,0.88);
}

