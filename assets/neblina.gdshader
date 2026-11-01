shader_type canvas_item;

// neblina/fumaça em pixel: duas camadas de ruído andando com o vento,
// cortadas em degraus pra combinar com o pixel art. recebe luz (fica colorida perto das lâmpadas)
uniform sampler2D ruido : repeat_enable, filter_linear;
uniform vec4 cor : source_color = vec4(0.8, 0.78, 0.95, 1.0);
uniform float densidade = 0.5;
uniform vec2 vento = vec2(0.01, 0.003);
// quantas vezes o ruído cabe no retângulo
uniform float escala = 2.0;
// tamanho do retângulo e do "pixel" da neblina, em px do mundo
uniform vec2 tamanho = vec2(1000.0, 1000.0);
uniform float pixel = 4.0;
uniform float degraus = 4.0;
// fração da borda que some suave (0 = corta reto)
uniform float borda = 0.0;

void fragment() {
	vec2 p = floor(UV * tamanho / pixel) * pixel / tamanho;
	vec2 proporcao = vec2(tamanho.x / tamanho.y, 1.0);
	float a = texture(ruido, p * proporcao * escala + TIME * vento).r;
	float b = texture(ruido, p * proporcao * escala * 1.9 - TIME * vento * 1.6 + 0.37).r;
	float n = smoothstep(0.42, 0.88, a * 0.65 + b * 0.35);
	n = ceil(n * degraus) / degraus;
	float some = 1.0;
	if (borda > 0.0) {
		vec2 e = min(p, 1.0 - p) / borda;
		some = clamp(min(e.x, e.y), 0.0, 1.0);
	}
	COLOR = vec4(cor.rgb, n * densidade * some);
}
