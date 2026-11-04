shader_type fog;
uniform float density=0.012;
void fog(){
    float edge=1.0-smoothstep(0.30,0.50,max(abs(UVW.x-0.5),abs(UVW.z-0.5)));
    float height=1.0-smoothstep(6.0,9.5,WORLD_POSITION.y);
    DENSITY=density*edge*height;
    ALBEDO=vec3(0.98,0.98,0.96);
}

