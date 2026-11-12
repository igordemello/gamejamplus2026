shader_type spatial;
// sprite de personagem (AnimatedSprite3D/Sprite3D): fica em pé virado pra câmera, recebe luz e sombra,
// e tem o contorno do hover e o brilho branco das piscadas
render_mode cull_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform bool contorno = false;
uniform vec4 cor_contorno : source_color = vec4(1.0);
uniform float brilho : hint_range(0.0, 1.0) = 0.0;
// fica de frente pra câmera só girando em volta do y (em pé)
uniform bool billboard = true;
// gira o desenho no plano dele em volta da origem (o pé), em radianos
uniform float giro = 0.0;

void vertex() {
	VERTEX.xy = mat2(vec2(cos(giro), sin(giro)), vec2(-sin(giro), cos(giro))) * VERTEX.xy;
	if (billboard) {
		vec3 direita = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 frente = normalize(cross(direita, vec3(0.0, 1.0, 0.0)));
		mat4 virado = mat4(vec4(direita, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(frente, 0.0), MODEL_MATRIX[3]);
		mat4 escala = mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * virado * escala;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec4 cor = texture(texture_albedo, UV);
	// pixel transparente encostado no desenho vira borda
	if (contorno && cor.a < 0.1) {
		vec2 p = 1.0 / vec2(textureSize(texture_albedo, 0));
		float vizinhos = texture(texture_albedo, UV + vec2(p.x, 0.0)).a + texture(texture_albedo, UV - vec2(p.x, 0.0)).a
			+ texture(texture_albedo, UV + vec2(0.0, p.y)).a + texture(texture_albedo, UV - vec2(0.0, p.y)).a;
		if (vizinhos > 0.0) {
			cor = cor_contorno;
		}
	}
	cor *= COLOR;
	ALBEDO = mix(cor.rgb, vec3(1.0), brilho);
	EMISSION = vec3(brilho);
	ALPHA = cor.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
