shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Névoa rasteira (plano horizontal). Recebe a luz das OmniLights (a fumaça da pista fica colorida).
// mascara: textura do chão da casa (opaca por dentro); a névoa só aparece onde ela é transparente.
// Sem máscara, a borda do plano (uv) some suavemente.
uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform sampler2D mascara : repeat_disable, filter_linear;
uniform bool usar_mascara = false;
uniform vec4 mascara_rect = vec4(0.0); // x, z do canto e tamanho (em unidades 3D) do sprite do chão
uniform vec2 tamanho_plano = vec2(1000.0);
uniform vec4 cor : source_color = vec4(0.5, 0.55, 0.7, 1.0);
uniform float densidade = 0.5;
uniform float escala = 0.0012;
uniform vec2 vento = vec2(0.012, 0.004);
uniform float corte = 0.3;
uniform float luz_propria = 0.0;

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = mundo.xz * escala;
	float a = texture(ruido, p + vento * TIME).r;
	float b = texture(ruido, p * 2.3 - vento * 1.7 * TIME + vec2(0.37, 0.61)).r;
	float n = smoothstep(corte, 1.0, a * 0.65 + b * 0.35);
	float m = 1.0;
	if (usar_mascara) {
		vec2 uv = (mundo.xz - mascara_rect.xy) / mascara_rect.zw;
		if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
			m = 1.0 - smoothstep(0.1, 0.9, textureLod(mascara, uv, 3.0).a);
		}
	} else {
		vec2 e = min(UV, 1.0 - UV) * 2.0;
		m = smoothstep(0.0, 0.6, min(e.x, e.y));
	}
	ALBEDO = cor.rgb;
	EMISSION = cor.rgb * luz_propria;
	ALPHA = clamp(n * densidade * m, 0.0, 1.0);
}
