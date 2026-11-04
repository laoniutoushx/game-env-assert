shader_type fog;
uniform vec3 ray_origin;
uniform vec3 ray_direction=vec3(0.6,-0.53,0.6);
uniform float ray_length=8.0;
uniform float density=0.06;
void fog(){
    vec3 d=WORLD_POSITION-ray_origin;
    float t=dot(d,ray_direction);
    float progress=clamp(t/ray_length,0.0,1.0);
    float radius=mix(0.12,0.65,progress);
    float radial=length(d-ray_direction*t);
    float shape=1.0-smoothstep(radius*0.45,radius,radial);
    shape*=smoothstep(0.0,0.5,t)*(1.0-smoothstep(ray_length-0.65,ray_length,t));
    DENSITY=density*shape;
    ALBEDO=vec3(0.98,0.98,0.96);
}
