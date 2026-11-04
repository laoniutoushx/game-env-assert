shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D base_map : source_color,filter_linear_mipmap;
void fragment(){ALBEDO=vec3(0,1,0);ALPHA=texture(base_map,UV).a;ALPHA_SCISSOR_THRESHOLD=0.45;}
