// 纸 —— 一个着色器顶掉大半张背景图。
//
// ============================================================
// 用它干三件事（不用画任何素材）：
//   ① 纤维颗粒 —— 纸不是纯色，有噪点
//   ② 大块不均 —— 中间亮、边上暗，像被灯照着
//   ③ 折痕     —— 两三条淡淡的折线，"这是一张真的纸"
//
// 怎么用：
//   场景里放一个全屏 ColorRect（或 TextureRect），
//   把这个 shader 拖到它的 Material 上。
//   然后调下面那几个 uniform 就行。
//
// ★ 同一个 shader 换个参数能演：
//     · 老照片褪色   —— 颗粒调大、saturation 调低
//     · 撕纸边       —— 用 noise 的阈值去裁 alpha
//     · 墨迹晕开     —— 后面再加一个模糊 pass
//
// 色值默认对应 脚本/数据/色板.gd 里的 纸 / 暗角。
shader_type canvas_item;

// 纸的本色
uniform vec4 paper_color : source_color = vec4(0.827, 0.780, 0.675, 1.0);
// 纸外面的黑（暗角）
uniform vec4 dark_color : source_color = vec4(0.078, 0.067, 0.055, 1.0);

// 纤维颗粒的强度
uniform float grain : hint_range(0.0, 1.0) = 0.35;
// 大块明暗的不均匀程度
uniform float mottle : hint_range(0.0, 1.0) = 0.16;
// 暗角强度（0 = 平铺一张纸，1 = 只有中间亮）
uniform float vignette : hint_range(0.0, 1.0) = 0.55;
// 折痕强度
uniform float crease : hint_range(0.0, 1.0) = 0.16;
// 纸的呼吸起伏（这个让它"活"）
uniform float breathe : hint_range(0.0, 0.03) = 0.006;
// 呼吸速度
uniform float breathe_speed : hint_range(0.0, 2.0) = 0.35;
// 整体明暗（做旧 / 变暗的时候调它）
uniform float exposure : hint_range(0.3, 1.5) = 1.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * vnoise(p);
		p *= 2.02;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	// ---- ① 纸在轻轻呼吸（UV 微扰，字会跟着一起微微动）----
	vec2 uv = UV;
	uv += vec2(
		sin(uv.y * 8.0 + TIME * breathe_speed) * breathe,
		cos(uv.x * 6.0 + TIME * breathe_speed * 0.8) * breathe
	);

	vec3 col = paper_color.rgb;

	// ---- ② 大块明暗 + 纤维颗粒 ----
	float coarse = fbm(uv * vec2(5.0, 6.5));
	float fine = fbm(uv * vec2(220.0, 300.0));
	col *= (1.0 - mottle * 0.5) + mottle * coarse * 1.6;
	col -= (fine - 0.5) * grain * 0.20;

	// ---- ③ 两三条折痕 ----
	// 每条折痕 = 一条被噪声抖动的直线
	for (int i = 0; i < 3; i++) {
		float ang = float(i) * 2.39996;          // 黄金角，三条折痕方向自然错开
		vec2 dir = vec2(cos(ang), sin(ang));
		// 偏移量随位置轻微摇摆 —— 折痕不是尺子画的
		float wob = (fbm(uv * vec2(3.0, 20.0) + float(i) * 17.0) - 0.5) * 0.03;
		float d = dot(uv - 0.5, dir) + wob;
		float line = smoothstep(0.010, 0.0, abs(d));
		col *= 1.0 - line * crease;
	}

	// ---- ④ 暗角：中间是被灯照到的地方，边上沉下去 ----
	vec2 vp = (UV - 0.5) * vec2(1.0, 0.74);
	float v = smoothstep(0.26, 0.80, length(vp));
	col = mix(col, dark_color.rgb, v * vignette);

	// ---- ⑤ 总曝光 ----
	col *= exposure;

	COLOR = vec4(col, paper_color.a);
}
