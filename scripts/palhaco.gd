extends Fantasma

@export var duracao_musica: float = 8.0
# quanto os sustos no cômodo ficam mais fortes enquanto a música toca (a House lê isso)
@export var intensidade_musica: float = 1.5
# segundos entre uma nota e outra subindo em volta dele
@export var intervalo_notas: float = 0.25
@export var duracao_nota: float = 1.4

@export var raio_balao: float = 250.0
@export var medo_balao: int = 30

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var notas: Node2D = $notas
# o arquivo e o volume vêm do som.gd
@onready var musica: AudioStreamPlayer2D = $musica
@onready var altura_sprite: float = sprite.position.y

# cômodo onde a música está tocando
var comodo_musica: String = ""
var tempo_musica: float = 0.0
var tempo_balanco: float = 0.0
var proxima_nota: float = 0.0
# cada nota é [posição, idade]
var lista_notas: Array = []
var alvo: Npc
var som_inflando: AudioStreamPlayer

func _ready() -> void:
	escala_sprite = sprite.scale
	sprite.frame_changed.connect(_on_quadro_mudou)
	sprite.animation_finished.connect(sprite.play.bind("parado"))
	notas.draw.connect(_desenhar_notas)

func _process(delta: float) -> void:
	super(delta)

	# flutua devagar; com música, dança de um lado pro outro
	tempo_balanco += delta
	sprite.position.y = altura_sprite + roundf(sin(tempo_balanco * 2.5) * 3.0)
	var giro = sin(tempo_balanco * 9.0) * 0.15 if tempo_musica > 0.0 else 0.0
	sprite.rotation = lerpf(sprite.rotation, giro, minf(10.0 * delta, 1.0))

	if tempo_musica > 0.0:
		tempo_musica -= delta
		proxima_nota -= delta
		if proxima_nota <= 0.0:
			proxima_nota = intervalo_notas
			# dos lados, pra não tampar a cara dele
			lista_notas.append([Vector2(randf_range(40.0, 130.0) * [-1, 1].pick_random(), randf_range(-110.0, 10.0)), 0.0])
		if tempo_musica <= 0.0:
			remove_from_group("musica")
			create_tween().set_ignore_time_scale().tween_property(musica, "volume_linear", 0.001, 0.4).finished.connect(musica.stop)

	for nota in lista_notas:
		nota[1] += delta
	lista_notas = lista_notas.filter(func(nota): return nota[1] < duracao_nota)
	notas.queue_redraw()

# música de circo no cômodo dele: todo susto lá dentro fica mais forte por um tempo
func musica_de_circo() -> bool:
	comodo_musica = GameManager.house.comodo_em(global_position)
	tempo_musica = duracao_musica
	proxima_nota = 0.0
	add_to_group("musica")
	musica.play(GameManager.som.preparar(musica, "musica_palhaco"))
	onomatopeia("LA LA LA", Color(1, 0.8, 0.4))
	return true

# a cabeça incha até virar aquela boca enorme e assusta quem está mais perto
func balao() -> bool:
	if sprite.animation == &"balao":
		return false
	var npc = npc_mais_perto()
	if npc == null or global_position.distance_to(npc.global_position) > raio_balao:
		return false
	alvo = npc
	sprite.play("balao")
	som_inflando = GameManager.som.tocar("balao_inflando")
	return true

# o susto sai no último quadro, com a boca toda aberta
func _on_quadro_mudou() -> void:
	if sprite.animation != &"balao" or sprite.frame != sprite.sprite_frames.get_frame_count("balao") - 1:
		return
	if is_instance_valid(alvo):
		onomatopeia("POP!", Color(1, 0.45, 0.55))
		alvo.tomar_susto("balao", medo_balao, self)
	alvo = null
	GameManager.som.parar(som_inflando, 0.05)
	GameManager.som.tocar("balao_estourando")
	GameManager.house.camera.tremer(5.0)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", escala_sprite * 1.3, 0.06)
	tween.tween_property(sprite, "scale", escala_sprite, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# notas brancas com borda preta subindo, balançando e sumindo
func _desenhar_notas() -> void:
	for nota in lista_notas:
		var vida = nota[1] / duracao_nota
		var alfa = minf(vida * 5.0, 1.0) * (1.0 - vida)
		var p = nota[0] + Vector2(sin(nota[1] * 6.0) * 6.0, -vida * 50.0)
		for camada in [[Color(0, 0, 0, alfa), 2.0], [Color(1, 1, 1, alfa), 0.0]]:
			var cor = camada[0]
			var borda = camada[1]
			notas.draw_circle(p, 7.0 + borda, cor)
			notas.draw_line(p + Vector2(6, 0), p + Vector2(6, -22), cor, 3.0 + borda * 2.0)
			notas.draw_line(p + Vector2(6, -22), p + Vector2(14, -15), cor, 3.0 + borda * 2.0)
