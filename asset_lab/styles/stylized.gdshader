shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, diffuse_burley, specular_schlick_ggx;

// ============================================================================
// 1. 纹理与基础表面配置
// ============================================================================
uniform sampler2D base_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform sampler2D orm_map : hint_default_white, filter_linear_mipmap;
uniform int orm_roughness_channel = 1;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform bool cutout = false;
uniform bool is_combined_mesh = false;
uniform int style = 1; // 1 = ② 手绘PBR标杆 (Stylized PBR), 2 = ③ 欧美卡通 (Cartoon)

// ============================================================================
// 2. 风格板 (Style Board) 核心色卡参数 (source_color 自动转为 Linear RGB)
// ============================================================================
uniform vec3 foliage_lit_color : source_color = vec3(0.710, 0.827, 0.353);    // #B5D35A 受光面清亮黄绿 (降黄升亮)
uniform vec3 foliage_mid_color : source_color = vec3(0.369, 0.604, 0.263);    // #5E9A43 中调饱满森林翠绿
uniform vec3 foliage_shadow_color : source_color = vec3(0.184, 0.353, 0.227); // #2F5A3A 暗部冷青绿偏蓝
uniform vec3 foliage_rim_color : source_color = vec3(0.780, 0.910, 0.440);    // #C7E870 背光叶团边缘轮廓透光色
uniform vec3 bark_lit_color : source_color = vec3(0.478, 0.365, 0.275);       // #7A5D46 树干受光暖棕
uniform vec3 bark_shadow_color : source_color = vec3(0.196, 0.173, 0.208);    // #322C35 树干暗部冷紫灰

// ============================================================================
// 3. 叶团法线、高度 AO、实例微扰与风动参数
// ============================================================================
uniform float normal_sphere_blend : hint_range(0.0, 1.0) = 0.80;
uniform float normal_cluster_blend : hint_range(0.0, 1.0) = 0.48;
uniform float cluster_scale : hint_range(0.4, 3.0) = 1.15;
uniform float canopy_bottom_darken : hint_range(0.0, 0.6) = 0.30; // 树冠底部压暗 30%
uniform float max_saturation : hint_range(0.3, 1.0) = 0.62;       // sRGB 饱和度上限 ≤ 65%
uniform float texture_detail_weight : hint_range(0.0, 1.0) = 0.32;// 借 ① 的材质微细节权重
uniform float rim_strength : hint_range(0.0, 1.5) = 0.45;         // 背光团块边缘轮廓光强度
uniform float instance_variation : hint_range(0.0, 1.0) = 1.0;    // ±5° 色相与 ±8% 明度实例微扰
uniform float wind_strength : hint_range(0.0, 1.0) = 0.12;        // 树冠微风摆动强度

// ============================================================================
// 4. 树空间几何基准 (由 prepare.gd 自动注入)
// ============================================================================
uniform mat4 tree_transform = mat4(1.0);
uniform vec3 canopy_center = vec3(0.0, 2.7, 0.0);
uniform float tree_height = 4.5;

varying float v_height_grad;
varying float v_canopy_ao;
varying float v_cluster_ao;
varying float v_vertex_foliage;
varying vec3 v_bent_normal_ws;
varying vec2 v_instance_rand;
varying float v_foliage_mask;
varying float v_detail_mod;

// RGB <-> HSV 工具函数 (在 sRGB 空间执行，确保与美术色板规范的百分比严格一致)
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 apply_srgb_hsv_constraints(vec3 linear_col, float hue_shift, float val_scale, float sat_cap) {
	vec3 srgb = pow(max(linear_col, vec3(0.0001)), vec3(1.0 / 2.2));
	vec3 hsv = rgb2hsv(srgb);
	hsv.x = fract(hsv.x + hue_shift);
	hsv.y = min(hsv.y, sat_cap);
	hsv.z = clamp(hsv.z * val_scale, 0.0, 1.0);
	return pow(hsv2rgb(hsv), vec3(2.2));
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

void vertex() {
	vec3 tree_pos = (tree_transform * vec4(VERTEX, 1.0)).xyz;
	v_height_grad = clamp(tree_pos.y / max(tree_height, 0.1), 0.0, 1.0);
	v_vertex_foliage = cutout ? 1.0 : (is_combined_mesh ? smoothstep(0.32, 0.50, v_height_grad) : 0.0);

	// 每实例哈希随机值 (基于世界坐标原点 MODEL_MATRIX[3].xyz)
	vec3 world_origin = MODEL_MATRIX[3].xyz;
	vec3 inst_h = hash33(round(world_origin * 10.0));
	float is_offset_instance = step(0.15, length(world_origin.xz));
	v_instance_rand = (inst_h.xy * 2.0 - 1.0) * instance_variation * is_offset_instance;

	// 轻柔叶团级微风摆动
	if (wind_strength > 0.001 && v_vertex_foliage > 0.05) {
		float wind_phase = TIME * 1.6 + dot(world_origin.xz, vec2(0.7, 0.5)) + tree_pos.x * 1.8;
		float sway = sin(wind_phase) * 0.032 * wind_strength * smoothstep(0.25, 0.9, v_height_grad);
		VERTEX.x += sway;
		VERTEX.z += cos(wind_phase * 0.85) * sway * 0.6;
	}

	// 1. 整体树冠球面外扩法线与径向深度 AO
	vec3 to_center = tree_pos - canopy_center;
	vec3 canopy_dir = normalize(vec3(to_center.x, to_center.y * 0.90 + 0.04, to_center.z));
	float radial_dist = length(to_center / vec3(1.60, 1.80, 1.60));
	v_canopy_ao = clamp(mix(0.45, 1.0, smoothstep(0.10, 0.88, radial_dist)), 0.0, 1.0);

	// 2. 叶团分组法线 (Sub-cluster Normal Bending)：将树冠切分为多个饱满叶团
	vec3 scaled_p = (tree_pos - vec3(0.0, 1.2, 0.0)) / max(cluster_scale, 0.3);
	vec3 cell_id = floor(scaled_p);
	vec3 cell_jitter = (hash33(cell_id) - 0.5) * 0.32;
	vec3 cluster_center = (cell_id + vec3(0.5) + cell_jitter) * cluster_scale + vec3(0.0, 1.2, 0.0);
	vec3 to_cluster = tree_pos - cluster_center;
	vec3 cluster_dir = normalize(vec3(to_cluster.x, to_cluster.y * 1.15 + 0.08, to_cluster.z));
	float cluster_bottom = smoothstep(-0.45 * cluster_scale, 0.38 * cluster_scale, to_cluster.y);
	v_cluster_ao = mix(0.76, 1.06, cluster_bottom);

	vec3 combined_sphere_tree = normalize(mix(canopy_dir, cluster_dir, normal_cluster_blend));
	vec3 sphere_dir_local = normalize((inverse(tree_transform) * vec4(combined_sphere_tree, 0.0)).xyz);
	v_bent_normal_ws = normalize((MODEL_MATRIX * vec4(sphere_dir_local, 0.0)).xyz);
}

void fragment() {
	float mip_bias = (style == 1) ? 0.45 : 1.35;
	vec4 c = texture(base_map, UV, mip_bias);
	if (cutout) {
		ALPHA = c.a;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}

	float green_dominance = c.g - max(c.r * 0.92, c.b * 1.05);
	float foliage_mask = cutout ? 1.0 : (is_combined_mesh ? smoothstep(-0.01, 0.05, green_dominance) * v_vertex_foliage : 0.0);
	v_foliage_mask = foliage_mask;

	// 叶团球面法线重定向（View Space 混合）
	if (foliage_mask > 0.01) {
		vec3 bent_normal_vs = normalize((VIEW_MATRIX * vec4(v_bent_normal_ws, 0.0)).xyz);
		float blend_amt = (style == 1) ? normal_sphere_blend : min(normal_sphere_blend + 0.14, 0.95);
		NORMAL = normalize(mix(NORMAL, bent_normal_vs, blend_amt * foliage_mask));
	}

	// 提取贴图中频细节因子（围绕 1.0 微幅波动，既保留叶脉/树皮肌理，又不破坏三色卡准确度）
	float tex_luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
	float norm_detail = clamp(tex_luma / max(mix(0.055, 0.075, foliage_mask), 0.01), 0.72, 1.25);
	float detail_w = (style == 1) ? texture_detail_weight : texture_detail_weight * 0.35;
	v_detail_mod = mix(1.0, norm_detail, detail_w);

	// ALBEDO 设为纯白基准 (1.0)，由 light() 直接输出精确受控的风格板三层明度色值，杜绝高光漂白
	ALBEDO = vec3(1.0);

	float tex_rough = (style == 1) ? 0.68 : 0.88;
	if (has_orm) {
		vec3 orm = texture(orm_map, UV).rgb;
		float r_val = (orm_roughness_channel == 1) ? orm.g : orm.r;
		if (style == 1 && r_val > 0.01) {
			tex_rough = clamp(mix(r_val, 0.65, 0.45), 0.42, 0.88);
		}
	}
	ROUGHNESS = mix(tex_rough + 0.10, tex_rough, foliage_mask);
	SPECULAR = (style == 1) ? 0.18 : 0.05;

	if (has_normal) {
		NORMAL_MAP = texture(normal_map, UV).rgb;
		float leaf_nrm_depth = (style == 1) ? 0.14 : 0.02;
		float bark_nrm_depth = (style == 1) ? 0.58 : 0.28;
		NORMAL_MAP_DEPTH = mix(bark_nrm_depth, leaf_nrm_depth, foliage_mask);
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ndl_clamped = max(ndl, 0.0);
	float is_leaf = clamp(v_foliage_mask, 0.0, 1.0);

	// 1. 树冠底部压暗 30% (Height Gradient AO)
	float canopy_height_ao = mix(1.0 - canopy_bottom_darken, 1.04, smoothstep(0.22, 0.86, v_height_grad));

	// 2. 树干与树冠交界处的明确压暗分隔 (Crown-Trunk Separation AO) + 树根接地 AO
	float trunk_root_ao = mix(0.58, 1.0, smoothstep(0.0, 0.24, v_height_grad));
	float trunk_under_canopy_ao = 1.0 - 0.45 * smoothstep(0.30, 0.50, v_height_grad);
	float trunk_ao = trunk_root_ao * trunk_under_canopy_ao;

	// 3. 综合球面法线受光、投影衰减、叶团凸起度与高度渐变，计算三层明度驱动值 shade_t
	float half_l = ndl * 0.5 + 0.5;
	float shadow_atten = mix(0.22, 1.0, ATTENUATION);
	float height_light_bias = mix(0.75, 1.12, smoothstep(0.22, 0.86, v_height_grad));
	float shade_t = half_l * shadow_atten * mix(1.0, height_light_bias * v_cluster_ao * mix(0.72, 1.04, v_canopy_ao), is_leaf);

	// 4. 三层明度色阶映射 (严格对齐色板: 冷暗 #2F5A3A -> 中调 #5E9A43 -> 受光 #B5D35A)
	float w1 = (style == 1) ? 0.08 : 0.035;
	float w2 = (style == 1) ? 0.09 : 0.040;
	float step_shadow_to_mid = smoothstep(0.34 - w1, 0.34 + w1, shade_t);
	float step_mid_to_lit = smoothstep(0.62 - w2, 0.62 + w2, shade_t);

	vec3 leaf_col = mix(foliage_shadow_color, foliage_mid_color, step_shadow_to_mid);
	leaf_col = mix(leaf_col, foliage_lit_color, step_mid_to_lit);
	leaf_col *= canopy_height_ao * v_detail_mod;

	// 5. 背光叶团边缘轮廓透光 (Rim / Backlight Translucency)
	float view_edge = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 2.6);
	float back_dir = smoothstep(-0.20, 0.65, dot(-LIGHT, NORMAL));
	float rim_mask = view_edge * mix(0.30, 1.0, back_dir) * smoothstep(0.30, 0.82, v_height_grad) * mix(0.4, 1.0, ATTENUATION);
	leaf_col = mix(leaf_col, foliage_rim_color, clamp(rim_mask * rim_strength, 0.0, 0.65));

	// 6. 在 sRGB 空间执行 ±5° 色相、±8% 明度实例微扰与 ≤65% 饱和度硬上限钳制
	float hue_offset = v_instance_rand.x * 0.014; // ±5° / 360°
	float val_scale = 1.0 + v_instance_rand.y * 0.08;
	leaf_col = apply_srgb_hsv_constraints(leaf_col, hue_offset, val_scale, max_saturation);

	// 7. 树干着色 (含交界分隔压暗)
	float bark_step = smoothstep(0.32, 0.62, half_l * shadow_atten);
	vec3 bark_col = mix(bark_shadow_color, bark_lit_color, bark_step) * trunk_ao * v_detail_mod;

	vec3 final_surface_col = mix(bark_col, leaf_col, is_leaf);

	// 响应场景灯光色温（归一化灯光强度以防止过曝漂白，确保石板路径始终最亮）
	vec3 norm_light = LIGHT_COLOR / max(max(LIGHT_COLOR.r, max(LIGHT_COLOR.g, LIGHT_COLOR.b)), 0.85);
	DIFFUSE_LIGHT += final_surface_col * norm_light;
}
