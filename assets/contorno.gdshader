shader_type canvas_item;

uniform vec4 cor : source_color = vec4(1.0);
uniform bool contorno = false;
uniform float brilho : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// pixel transparente encostado num pixel do sprite vira borda
	if (contorno && COLOR.a < 0.1) {
		vec2 p = TEXTURE_PIXEL_SIZE;
		float vizinhos = texture(TEXTURE, UV + vec2(p.x, 0.0)).a
			+ texture(TEXTURE, UV - vec2(p.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, p.y)).a
			+ texture(TEXTURE, UV - vec2(0.0, p.y)).a;
		if (vizinhos > 0.0) {
			COLOR = cor;
		}
	}
	COLOR.rgb = mix(COLOR.rgb, cor.rgb, brilho);
}
