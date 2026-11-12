shader_type spatial;

// Parede da casa 2.5D: topo escuro (COLOR.a = 0) e faces no marrom/bege da arte (COLOR.rgb),
// com listras de papel de parede sutis, rodapé mais escuro e escurecimento leve embaixo.
// A altura vem do próprio mundo 3D: y * cos(ANGULO) = pixels de tela acima do chão (ver scripts/vista3d.gd).

uniform float cos_angulo = 0.6427876;
uniform float altura_parede = 64.0;
uniform float periodo_listra = 24.0;
uniform float forca_listra = 0.07;
uniform float altura_rodape = 12.0;

varying vec3 mundo;
varying float topo;
varying float lateral;

float ruido(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	topo = step(0.5, NORMAL.y);
	lateral = step(0.5, abs(NORMAL.x));
}

void fragment() {
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	if (topo > 0.5) {
		ALBEDO = COLOR.rgb;
	} else {
		float h = mundo.y * cos_angulo;
		float u = mix(mundo.x, mundo.z, lateral);
		// listras suaves, mais escuras e mais claras que a base
		float listra = smoothstep(0.35, 0.65, abs(fract(u / periodo_listra) - 0.5) * 2.0);
		float k = 1.0 + (listra - 0.5) * 2.0 * forca_listra;
		// grão de papel
		k *= 1.0 + (ruido(vec2(u, h) / 3.0) - 0.5) * 0.04;
		// rodapé: faixa escura com um fio claro no alto
		if (h < altura_rodape) {
			k *= 0.62;
		} else if (h < altura_rodape + 2.0) {
			k *= 1.18;
		}
		// mais escuro perto do chão
		k *= mix(0.78, 1.0, smoothstep(0.0, altura_parede, h));
		ALBEDO = COLOR.rgb * k;
	}
}
