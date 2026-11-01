shader_type canvas_item;

// pós-processamento da casa: cor de noite de halloween (escuros puxando pro roxo,
// claros quentes), vinheta, granulado e aberração cromática que dá um tranco nos sustos
uniform sampler2D tela : hint_screen_texture, filter_nearest;
uniform vec3 cor_sombra : source_color = vec3(0.09, 0.03, 0.14);
uniform vec3 cor_luz : source_color = vec3(1.06, 0.98, 0.9);
uniform float saturacao = 1.15;
uniform float contraste = 1.08;
uniform float vinheta = 0.55;
uniform float grao = 0.025;
// em pixels de tela, na borda
uniform float aberracao = 1.0;

float acaso(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 meio = uv - 0.5;
	float proporcao = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float d = length(meio * vec2(proporcao, 1.0));

	// cada canal desloca um pouco pra fora, mais nas bordas
	vec2 desvio = normalize(meio + 0.0001) * aberracao * d * 2.0 * SCREEN_PIXEL_SIZE;
	vec3 c = vec3(texture(tela, uv + desvio).r, texture(tela, uv).g, texture(tela, uv - desvio).b);

	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, saturacao);
	c = (c - 0.5) * contraste + 0.5;
	c += cor_sombra * pow(1.0 - clamp(lum, 0.0, 1.0), 3.0);
	c *= mix(vec3(1.0), cor_luz, clamp(lum, 0.0, 1.0));

	c *= 1.0 - vinheta * smoothstep(0.45, 1.05, d);
	// granulado de 2 em 2 pixels de tela, muda todo frame
	c += (acaso(floor(FRAGCOORD.xy / 2.0) + fract(TIME) * 100.0) - 0.5) * grao;
	COLOR = vec4(c, 1.0);
}
