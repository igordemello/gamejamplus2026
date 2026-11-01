shader_type canvas_item;
render_mode unshaded;

// silhueta branca (a alma do npc que infartou); ignora a noite e as luzes
void fragment() {
	COLOR.rgb = vec3(1.0);
}
