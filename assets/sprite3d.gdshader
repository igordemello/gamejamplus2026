shader_type spatial;
// desenho 2D (quadro de um AnimatedSprite2D/Sprite2D) num billboard 3D: recebe luz e tem o mesmo
// contorno/brilho do contorno.gdshader do 2D. O quad visível fica de frente pra câmera (pixel quadrado em
// qualquer ângulo), mas a profundidade escrita é a do plano em pé no pé dele: a parede da frente tampa, a de
// trás não, como o Y-sort do 2D. A sombra sai de outra malha com o mesmo material, em pé (so_sombra = 1).
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert_wrap, specular_disabled;

uniform sampler2D tex_pixel : source_color, filter_nearest, repeat_disable;
uniform sampler2D tex_suave : source_color, filter_linear_mipmap, repeat_disable;
uniform bool pixel = true;
// região do quadro no atlas (uv): xy = começo, zw = tamanho
uniform vec4 regiao = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 espelhar = vec2(0.0);
uniform vec4 cor : source_color = vec4(1.0);
uniform bool contorno = false;
uniform vec4 cor_contorno : source_color = vec4(1.0);
uniform float brilho = 0.0;
// tamanho de um texel do atlas (uv)
uniform vec2 texel = vec2(0.01);
// plano em pé do desenho (mundo): ponto do pé e normal horizontal virada pra câmera
uniform vec3 pe = vec3(0.0);
uniform vec3 normal_pe = vec3(0.0, 0.0, 1.0);
instance uniform float so_sombra = 0.0;

vec4 ler(vec2 uv) {
	return pixel ? texture(tex_pixel, uv) : texture(tex_suave, uv);
}

// transparência por pontilhado (bayer 4x4): funciona com profundidade e sombra
float limiar(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec2 uv = mix(UV, 1.0 - UV, espelhar);
	vec2 t = regiao.xy + uv * regiao.zw;
	vec4 c = ler(t);
	if (contorno && c.a < 0.1) {
		vec2 lo = regiao.xy;
		vec2 hi = regiao.xy + regiao.zw;
		float v = 0.0;
		v += ler(clamp(t + vec2(texel.x, 0.0), lo, hi)).a;
		v += ler(clamp(t - vec2(texel.x, 0.0), lo, hi)).a;
		v += ler(clamp(t + vec2(0.0, texel.y), lo, hi)).a;
		v += ler(clamp(t - vec2(0.0, texel.y), lo, hi)).a;
		if (v > 0.0) {
			c = cor_contorno;
		}
	}
	c.rgb = mix(c.rgb, cor_contorno.rgb, brilho);
	c *= cor;
	if (c.a < 0.02 || c.a < limiar(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = c.rgb;
	// raio da câmera por este pixel até o plano em pé (ortográfica: raio paralelo)
	float profundidade = FRAGCOORD.z;
	if (so_sombra < 0.5) {
		bool orto = PROJECTION_MATRIX[3][3] > 0.5;
		vec3 origem = orto ? vec3(VERTEX.xy, 0.0) : vec3(0.0);
		vec3 direcao = orto ? vec3(0.0, 0.0, -1.0) : normalize(VERTEX);
		vec3 p = (VIEW_MATRIX * vec4(pe, 1.0)).xyz;
		vec3 n = normalize((VIEW_MATRIX * vec4(normal_pe, 0.0)).xyz);
		float d = dot(direcao, n);
		if (abs(d) > 0.0001) {
			vec3 acerto = origem + direcao * (dot(p - origem, n) / d);
			vec4 clip = PROJECTION_MATRIX * vec4(acerto, 1.0);
			profundidade = clip.z / clip.w;
		}
	}
	DEPTH = profundidade;
	// virado pra câmera e um pouco pra cima: a luz de cima e da frente acende o desenho
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 0.4, 1.0, 0.0)).xyz);
}
