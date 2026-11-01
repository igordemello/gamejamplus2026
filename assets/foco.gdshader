shader_type canvas_item;

// escurece a tela toda menos um círculo em volta de "centro" (UV da tela);
// raio em fração da altura da tela
uniform vec2 centro = vec2(0.5);
uniform float raio = 0.6;
uniform float forca = 0.0;
uniform float proporcao = 1.7778;

void fragment() {
	vec2 d = (UV - centro) * vec2(proporcao, 1.0);
	float escuro = smoothstep(raio, raio + 0.15, length(d));
	COLOR = vec4(0.0, 0.0, 0.0, escuro * forca);
}
