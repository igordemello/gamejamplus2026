extends Node3D

# invocação de fantasma comprado na loja: o pentagrama se desenha no chão, brilha,
# solta brasas e, no clarão, o fantasma sai do meio dele. a area_jogo cria isso em fase.mundo,
# no lugar do spawn (põe global_position logo depois do add_child)

# quem estiver a esse raio (m) do pentagrama leva um susto pequeno quando o fantasma sai
@export var raio_susto: float = 1.82
@export var medo_susto: int = 20

var fantasma: Fantasma
var tempo: float = 0.0
var brilho: float = 1.0
var alfa: float = 1.0

@onready var pentagrama: AnimatedSprite3D = $pentagrama
@onready var luz: OmniLight3D = $luz
@onready var brasas: GPUParticles3D = $brasas

func _ready() -> void:
	pentagrama.play("desenhar")
	GameManager.som.tocar("ritual")
	pentagrama.animation_finished.connect(_on_desenhou)
	create_tween().tween_property(luz, "light_energy", 2.5, pentagrama.sprite_frames.get_frame_count("desenhar") / pentagrama.sprite_frames.get_animation_speed("desenhar"))
	brasas.emitting = true

func _process(delta: float) -> void:
	tempo += delta
	# vai pulsando cada vez mais rápido enquanto se desenha
	var v = brilho + 0.35 * sin(tempo * (8.0 + tempo * 10.0))
	pentagrama.modulate = Color(v, v, v, alfa)

func _on_desenhou() -> void:
	# segura um instante aceso no máximo e solta o fantasma no clarão
	var tween = create_tween()
	tween.tween_property(self, "brilho", 2.2, 0.25)
	tween.tween_callback(_soltar_fantasma)
	tween.tween_property(self, "brilho", 1.0, 0.3)
	tween.tween_interval(0.5)
	tween.tween_property(self, "alfa", 0.0, 0.6)
	tween.parallel().tween_property(luz, "light_energy", 0.0, 0.6)
	tween.tween_callback(queue_free)

func _soltar_fantasma() -> void:
	var fase = GameManager.fase
	fase.mundo.add_child(fantasma)
	fantasma.global_position = global_position
	fantasma.aparecer()
	luz.light_energy = 6.0
	brasas.emitting = false
	fase.camera.tremer(4.0)
	# o zumbi fica lá fora: a câmera afasta pra mostrar onde ele está
	if fantasma.fora_de_casa:
		fase.camera.mostrar_exterior()
	fase.pos.chutar(3.0)
	fase.piscar_luzes(global_position, 0.3)
	Onomatopeia.soltar("VUUSH!", global_position + Vector3.UP * 1.0, Color(1, 0.35, 0.3))
	GameManager.som.tocar("vush")
	assustar_perto()

# o clarão assusta quem está em volta do pentagrama
func assustar_perto() -> void:
	var perto = get_tree().get_nodes_in_group("npc").filter(func(npc): return global_position.distance_to(npc.global_position) <= raio_susto)
	var medo = fantasma.medo_em_grupo(medo_susto, perto.size())
	fantasma.sentir_grupo(perto, global_position)
	for npc in perto:
		npc.tomar_susto("invocacao", medo, fantasma)
	if not perto.is_empty():
		GameManager.som.tocar("buu_invocacao")
		Onomatopeia.soltar(["BU!", "AAAH!"].pick_random(), global_position + Vector3(randf_range(-0.8, 0.8), 1.7, 0), Color(1, 0.95, 0.6))
