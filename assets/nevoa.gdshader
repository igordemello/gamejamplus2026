shader_type spatial;
// Névoa rasteira em camadas: cada camada é um plano deitado com fiapos de ruído andando com o vento.
// Várias empilhadas em alturas diferentes dão volume quando a câmera mexe. Recebe as luzes (a fumaça
// da pista fica colorida), some suave onde encosta em parede, chão ou gente, e com a máscara
// não entra na casa.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

uniform sampler2D ruido : repeat_enable, filter_linear_mipmap;
uniform sampler2D profundidade : hint_depth_texture, filter_nearest;
uniform vec4 cor : source_color = vec4(0.45, 0.5, 0.7, 1.0);
uniform float densidade = 0.25;
// tamanho dos fiapos: maior = fiapos menores
uniform float escala = 0.1;
uniform vec2 vento = vec2(0.012, 0.005);
// abaixo disso o ruído vira buraco (mais alto = névoa mais rala)
uniform float corte = 0.35;
// em metros: quanto antes de encostar em algo a névoa começa a sumir
uniform float suavidade = 0.5;
uniform float luz_propria = 0.15;
// imagem do chão da casa: onde ela é opaca não tem névoa. retangulo = (x, z, largura, profundidade)
uniform bool usar_mascara = false;
uniform sampler2D mascara : repeat_disable, filter_linear_mipmap;
uniform vec4 retangulo = vec4(0.0, 0.0, 10.0, 10.0);
// cada camada da pilha: mexe o ruído pra não repetir e afina a névoa (0 = camada de baixo)
instance uniform float camada = 0.0;
instance uniform float forca = 1.0;

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = mundo.xz * escala + vec2(camada * 0.37, camada * 0.61);
	float a = texture(ruido, p + vento * TIME).r;
	float b = texture(ruido, p * 2.1 - vento * 1.6 * TIME + vec2(0.4, 0.7)).r;
	float n = smoothstep(corte, 1.0, a * 0.65 + b * 0.35);

	// borda do plano some devagar
	vec2 borda = min(UV, 1.0 - UV) * 2.0;
	float m = smoothstep(0.0, 0.5, min(borda.x, borda.y));
	if (usar_mascara) {
		vec2 uv = (mundo.xz - retangulo.xy) / retangulo.zw;
		if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
			// mipmap borrado: a névoa vai sumindo perto da parede em vez de cortar reto
			m *= 1.0 - smoothstep(0.05, 0.6, textureLod(mascara, uv, 4.0).a);
		}
	}

	// o que já está desenhado atrás: perto dele a névoa some (sem linha dura no chão e nas paredes)
	float d = texture(profundidade, SCREEN_UV).r;
	vec4 cena = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	cena.xyz /= cena.w;
	float perto = clamp((VERTEX.z - cena.z) / suavidade, 0.0, 1.0);

	ALBEDO = cor.rgb;
	EMISSION = cor.rgb * luz_propria;
	ALPHA = clamp(n * densidade * forca * m * perto, 0.0, 1.0);
}
