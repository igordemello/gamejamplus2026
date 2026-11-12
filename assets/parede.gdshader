shader_type spatial;
// parede: topo escuro, face voltada pra dentro da casa marrom e pra fora bege. Dentro/fora é decidido
// olhando a imagem do chão da casa logo na frente da face, então qualquer peça nova pinta certo
render_mode cull_back;

uniform sampler2D chao : source_color, filter_linear;
uniform vec4 retangulo = vec4(0.0, 0.0, 10.0, 10.0);
uniform vec4 cor_dentro : source_color = vec4(0.5, 0.345, 0.235, 1.0);
uniform vec4 cor_fora : source_color = vec4(0.745, 0.68, 0.525, 1.0);
uniform vec4 cor_topo : source_color = vec4(0.02, 0.02, 0.025, 1.0);

varying vec3 mundo;
varying vec3 normal_mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (normal_mundo.y > 0.5) {
		ALBEDO = cor_topo.rgb;
	} else {
		vec2 frente = mundo.xz + normal_mundo.xz * 0.2;
		float tem_chao = texture(chao, (frente - retangulo.xy) / retangulo.zw).a;
		ALBEDO = tem_chao > 0.5 ? cor_dentro.rgb : cor_fora.rgb;
	}
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
