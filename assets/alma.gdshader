shader_type spatial;
// silhueta branca meio transparente (a alma do npc que infartou, a prévia do fantasma no ponto de spawn)
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform float opacidade = 1.0;
uniform bool billboard = true;

void vertex() {
	if (billboard) {
		vec3 direita = normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz));
		vec3 frente = normalize(cross(direita, vec3(0.0, 1.0, 0.0)));
		mat4 virado = mat4(vec4(direita, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(frente, 0.0), MODEL_MATRIX[3]);
		mat4 escala = mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * virado * escala;
	}
}

void fragment() {
	ALBEDO = vec3(1.0);
	ALPHA = texture(texture_albedo, UV).a * COLOR.a * opacidade;
}
