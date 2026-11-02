shader_type canvas_item;
render_mode unshaded;

// borda clara em volta do objeto que dá pra levitar; o miolo continua recebendo a cor da noite
uniform vec4 cor : source_color = vec4(1.0);
uniform vec4 noite : source_color = vec4(0.45, 0.42, 0.6, 1.0);

void fragment() {
	if (COLOR.a < 0.1) {
		vec2 p = TEXTURE_PIXEL_SIZE;
		// dois pixels de borda, senão some com a câmera afastada
		float vizinhos = 0.0;
		for (float i = 1.0; i <= 2.0; i += 1.0) {
			vizinhos += texture(TEXTURE, UV + vec2(p.x * i, 0.0)).a
				+ texture(TEXTURE, UV - vec2(p.x * i, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, p.y * i)).a
				+ texture(TEXTURE, UV - vec2(0.0, p.y * i)).a;
		}
		COLOR = vizinhos > 0.0 ? cor : vec4(0.0);
	} else {
		COLOR.rgb *= noite.rgb;
	}
}
