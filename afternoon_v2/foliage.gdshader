shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, alpha_to_coverage;
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D ao_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform bool has_ao = false;
uniform bool has_orm = false;
uniform bool orm_has_ao = false;
uniform float roughness_factor = 1.0;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform bool coverage_enabled = true;
uniform float normal_strength = 1.0;
uniform float wind_strength = 0.0;
uniform float leaf_surface = 1.0;
uniform vec3 species_tint : source_color = vec3(1.0);
uniform vec3 warm_leaf_tint = vec3(1.0);
uniform bool canopy_openings=false;
uniform vec3 lightpath_origins[3];
uniform vec3 lightpath_direction=vec3(0.6,-0.53,0.6);
varying vec3 canopy_world;
instance uniform vec4 plant_palette=vec4(1.0);
varying vec3 plant_tint;
void vertex() {
    float root_lock = smoothstep(0.02,0.45,VERTEX.y);
    float phase = dot(MODEL_MATRIX[3].xz,vec2(0.71,0.37));
    VERTEX.x += sin(TIME*1.1+phase+VERTEX.y*1.3)*root_lock*wind_strength*leaf_surface;
    VERTEX.z += cos(TIME*0.83+phase+VERTEX.x)*root_lock*wind_strength*0.5*leaf_surface;
    canopy_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    plant_tint=INSTANCE_CUSTOM.a>0.5?INSTANCE_CUSTOM.rgb:plant_palette.rgb;
}
void fragment() {
    if(!FRONT_FACING){NORMAL=-NORMAL;}
    vec4 base = texture(base_map,UV)*source_tint;
    if(base.a<0.001){discard;}
    if(canopy_openings && leaf_surface>0.5 && canopy_world.y>1.8 && canopy_world.x< -5.0 && canopy_world.z<0.5){
        for(int i=0;i<3;i++){
            vec3 delta=canopy_world-lightpath_origins[i];
            float t=dot(delta,lightpath_direction);
            if(t>0.0 && t<10.0 && length(delta-lightpath_direction*t)<0.38){discard;}
        }
    }
    // Subpixel leaf microdetail fades continuously; silhouette/alpha stay full resolution.
    float detail=1.0-smoothstep(22.0,30.0,length(VERTEX));
    vec3 orm = vec3(1.0,0.8,0.0);
    if(detail>0.001 && has_orm){orm=mix(orm,texture(orm_map,UV).rgb,detail);}
    float leaf = smoothstep(0.005,0.07,base.g-base.r)*leaf_surface;
    ALBEDO = base.rgb*species_tint*plant_tint;
    NORMAL_MAP = vec3(0.5,0.5,1.0);
    if(detail>0.001){NORMAL_MAP=mix(NORMAL_MAP,texture(normal_map,UV).rgb,detail);}
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = clamp((has_orm?orm.g:1.0)*roughness_factor,0.42,0.95);
    METALLIC = 0.0;
    SPECULAR = mix(0.28,0.30,leaf);
    BACKLIGHT = ALBEDO*leaf*0.30;
    float source_ao = orm_has_ao?orm.r:1.0;
    if(has_ao && detail>0.001){source_ao=mix(1.0,texture(ao_map,UV).r,detail);}
    AO = mix(1.0,source_ao,0.65);
    AO_LIGHT_AFFECT = 0.15;
    ALPHA = base.a;
    ALPHA_SCISSOR_THRESHOLD = 0.45;
    ALPHA_ANTIALIASING_EDGE = coverage_enabled?0.3:0.0;
    ALPHA_TEXTURE_COORDINATE = UV*vec2(textureSize(base_map,0));
}
