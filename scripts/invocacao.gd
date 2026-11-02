extends Node2D

# invocação de fantasma comprado na loja: o pentagrama se desenha no chão, brilha,
# solta brasas e, no clarão, o fantasma sai do meio dele. a area_jogo cria isso no lugar do spawn

# quem estiver a esse raio do pentagrama leva um susto pequeno quando o fantasma sai
@export var raio_susto: float = 160.0
@export var medo_susto: int = 20

var fantasma: Fantasma
var tempo: float = 0.0
var brilho: float = 1.0

@onready var pentagrama: AnimatedSprite2D = $pentagrama
@onready var luz: PointLight2D = $luz
@onready var brasas: CPUParticles2D = $brasas

func _ready() -> void:
	pentagrama.play("desenhar")
	GameManager.som.tocar("ritual")
	pentagrama.animation_finished.connect(_on_desenhou)
	create_tween().tween_property(luz, "energy", 1.4, pentagrama.sprite_frames.get_frame_count("desenhar") / pentagrama.sprite_frames.get_animation_speed("desenhar"))
	brasas.emitting = true
	# o pentagrama vai pra base do desenho do fantasma (cada um tem a origem num lugar), centralizado nele
	var sprite: AnimatedSprite2D = fantasma.get_node("AnimatedSprite2D")
	var quadro = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	var pe = (sprite.position + (sprite.offset + Vector2(0, quadro.get_height() / 2.0)) * sprite.scale) * fantasma.scale
	for filho in [pentagrama, luz, brasas]:
		filho.position += pe

func _process(delta: float) -> void:
	tempo += delta
	# vai pulsando cada vez mais rápido enquanto se desenha
	pentagrama.modulate = Color.WHITE * (brilho + 0.35 * sin(tempo * (8.0 + tempo * 10.0)))
	pentagrama.modulate.a = 1.0

func _on_desenhou() -> void:
	# segura um instante aceso no máximo e solta o fantasma no clarão
	var tween = create_tween()
	tween.tween_property(self, "brilho", 2.2, 0.25)
	tween.tween_callback(_soltar_fantasma)
	tween.tween_property(self, "brilho", 1.0, 0.3)
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(luz, "energy", 0.0, 0.6)
	tween.tween_callback(queue_free)

func _soltar_fantasma() -> void:
	var house = GameManager.house
	house.y_sort.add_child(fantasma)
	fantasma.global_position = global_position
	fantasma.aparecer()
	luz.energy = 3.0
	brasas.emitting = false
	house.camera.tremer(4.0)
	# o zumbi fica lá fora: a câmera afasta pra mostrar onde ele está
	if fantasma.fora_de_casa:
		house.camera.mostrar_exterior()
	house.pos.chutar(3.0)
	house.piscar_luzes(global_position, 0.3)
	Onomatopeia.soltar("VUUSH!", global_position + Vector2(0, -90), Color(1, 0.35, 0.3))
	GameManager.som.tocar("vush")
	assustar_perto()

# o clarão assusta quem está em volta do pentagrama
func assustar_perto() -> void:
	var perto = get_tree().get_nodes_in_group("npc").filter(func(npc): return pentagrama.global_position.distance_to(npc.global_position) <= raio_susto)
	var medo = fantasma.medo_em_grupo(medo_susto, perto.size())
	fantasma.sentir_grupo(perto, pentagrama.global_position)
	for npc in perto:
		npc.tomar_susto("invocacao", medo, fantasma)
	if not perto.is_empty():
		GameManager.som.tocar("buu_invocacao")
		Onomatopeia.soltar(["BU!", "AAAH!"].pick_random(), global_position + Vector2(randf_range(-70.0, 70.0), -150.0), Color(1, 0.95, 0.6))
