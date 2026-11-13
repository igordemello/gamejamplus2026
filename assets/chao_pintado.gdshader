shader_type spatial;
// chão com uma imagem pintada presa no mundo: qualquer peça colocada em cima da área da imagem
// mostra o pedaço certo dela. retangulo = (x, z, largura, profundidade) da imagem em metros.
// fora do retângulo a imagem se repete espelhada (a grama vai até o horizonte sem emenda)
render_mode cull_disabled;

uniform sampler2D textura : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 retangulo = vec4(0.0, 0.0, 10.0, 10.0);
// chão da casa: some onde a imagem é transparente e fora do retângulo
uniform bool recortar = false;
uniform vec4 tom : source_color = vec4(1.0);

varying vec3 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (mundo.xz - retangulo.xy) / retangulo.zw;
	vec2 espelhado = abs(mod(uv + 1.0, 2.0) - 1.0);
	// derivada do uv sem dobra: sem isso o mipmap erra na linha do espelho
	vec4 cor = textureGrad(textura, espelhado, dFdx(uv), dFdy(uv));
	bool dentro = uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0;
	if (recortar && (!dentro || cor.a < 0.5)) {
		discard;
	}
	ALBEDO = cor.rgb * tom.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
