shader_type spatial;
// chão com uma imagem pintada presa no mundo: qualquer peça colocada em cima da área da imagem
// mostra o pedaço certo dela. retangulo = (x, z, largura, profundidade) da imagem em metros
render_mode cull_disabled;

uniform sampler2D textura : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 retangulo = vec4(0.0, 0.0, 10.0, 10.0);
// chão da casa: some onde a imagem é transparente. grama: fora da imagem usa cor_fora
uniform bool recortar = false;
uniform vec4 cor_fora : source_color = vec4(0.1, 0.12, 0.1, 1.0);
uniform vec4 tom : source_color = vec4(1.0);

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (mundo.xz - retangulo.xy) / retangulo.zw;
	vec4 cor = texture(textura, uv);
	bool dentro = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
	if (recortar && (!dentro || cor.a < 0.5)) {
		discard;
	}
	ALBEDO = (dentro ? cor.rgb : cor_fora.rgb) * tom.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
