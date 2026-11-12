shader_type fog;
// neblina volumétrica de verdade (FogVolume): ruído 3D andando com o vento, mais densa embaixo e
// sumindo nas bordas do volume. Com mascara, some onde a imagem do chão da casa é opaca (não entra em casa)

uniform sampler3D ruido;
uniform float densidade = 0.6;
uniform vec4 cor : source_color = vec4(0.55, 0.6, 0.75, 1.0);
uniform vec3 vento = vec3(0.12, 0.0, 0.06);
uniform float escala = 0.18;
// 0..1: quanto da altura do volume a neblina ocupa antes de sumir
uniform float altura = 0.7;
uniform float corte = 0.35;
uniform bool usar_mascara = false;
uniform sampler2D mascara : filter_linear;
uniform vec4 retangulo = vec4(0.0, 0.0, 10.0, 10.0);

void fog() {
	float n = texture(ruido, WORLD_POSITION * escala + vento * TIME).r;
	float d = densidade * smoothstep(corte, 1.0, n);
	d *= 1.0 - smoothstep(altura * 0.4, altura, UVW.y);
	vec3 borda = min(UVW, 1.0 - UVW);
	d *= smoothstep(0.0, 0.12, min(borda.x, borda.z));
	if (usar_mascara) {
		vec2 uv = (WORLD_POSITION.xz - retangulo.xy) / retangulo.zw;
		d *= 1.0 - texture(mascara, uv).a;
	}
	DENSITY = d;
	ALBEDO = cor.rgb;
}
