extends Marker3D

# lugar da festa onde os npcs param pra fazer algo (pista, bebida, roda de conversa)

@export_enum("dançar", "beber", "conversar", "descansar", "banheiro") var atividade: String = "conversar"
@export var vagas: int = 3
# os npcs se espalham em volta do ponto até essa distância (metros)
@export var raio: float = 0.6
@export var tempo_min: float = 10.0
@export var tempo_max: float = 25.0

var ocupantes: Array = []

func _enter_tree() -> void:
	add_to_group("ponto_festa")

func tem_vaga() -> bool:
	ocupantes = ocupantes.filter(func(npc): return is_instance_valid(npc))
	return ocupantes.size() < vagas

# um lugar em volta do ponto, fora de parede e o mais longe possível de quem já vai ficar aqui
func lugar_livre() -> Vector3:
	var melhor = global_position
	var folga = -1.0
	for i in 8:
		var angulo = randf() * TAU
		var lugar = global_position + Vector3(cos(angulo), 0.0, sin(angulo)) * randf_range(raio * 0.4, raio)
		if GameManager.fase.eh_parede(lugar):
			continue
		var perto = INF
		for npc in ocupantes:
			perto = minf(perto, npc.agent.target_position.distance_to(lugar))
		if perto > folga:
			folga = perto
			melhor = lugar
	return melhor
