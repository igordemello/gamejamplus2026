# Palhaço: música de circo reforça os sustos do cômodo; balão assusta o mais perto.
extends Fantasma

@export var duracao_musica: float = 8.0
# quanto os sustos no cômodo ficam mais fortes enquanto a música toca (a House lê isso)
@export var intensidade_musica: float = 1.5
# segundos entre uma nota e outra subindo em volta dele
@export var intervalo_notas: float = 0.25
@export var duracao_nota: float = 1.4

@export var raio_balao: float = 2.84
@export var medo_balao: int = 36

@onready var sprite: SpritePersonagem = $sprite
@onready var notas: Node3D = $notas
# o arquivo e o volume vêm do som.gd
@onready var musica: AudioStreamPlayer3D = $musica
@onready var altura_sprite: float = sprite.position.y

# cômodo onde a música está tocando
var comodo_musica: String = ""
var tempo_musica: float = 0.0
var tempo_balanco: float = 0.0
var proxima_nota: float = 0.0
# cada nota é [Sprite3D, posição, idade]
var lista_notas: Array = []
var alvo: Npc
var som_inflando: AudioStreamPlayer

func _ready() -> void:
	escala_sprite = sprite.scale
	sprite.frame_changed.connect(_on_quadro_mudou)
	sprite.animation_finished.connect(sprite.play.bind("parado"))

func area_de(acao: Acao) -> Dictionary:
	return area_comodo() if acao.metodo == &"musica_de_circo" else area_raio(raio_balao)

func ocupado() -> bool:
	return sprite.animation == &"balao"

func _process(delta: float) -> void:
	super(delta)

	# flutua devagar; com música, dança de um lado pro outro
	tempo_balanco += delta
	sprite.position.y = altura_sprite + sin(tempo_balanco * 2.5) * 0.034
	var giro = sin(tempo_balanco * 9.0) * 0.15 if tempo_musica > 0.0 else 0.0
	sprite.giro = lerpf(sprite.giro, giro, minf(10.0 * delta, 1.0))

	if tempo_musica > 0.0:
		tempo_musica -= delta
		proxima_nota -= delta
		if proxima_nota <= 0.0:
			proxima_nota = intervalo_notas
			# dos lados, pra não tampar a cara dele
			lista_notas.append([nova_nota(), Vector3(randf_range(0.45, 1.5) * [-1, 1].pick_random(), randf_range(-0.1, 1.25), 0.1), 0.0])
		if tempo_musica <= 0.0:
			remove_from_group("musica")
			create_tween().set_ignore_time_scale().tween_property(musica, "volume_linear", 0.001, 0.4).finished.connect(musica.stop)

	for nota in lista_notas:
		nota[2] += delta
		var vida = nota[2] / duracao_nota
		nota[0].position = nota[1] + Vector3(sin(nota[2] * 6.0) * 0.07, vida * 0.57, 0)
		nota[0].modulate.a = minf(vida * 5.0, 1.0) * (1.0 - vida)
	for nota in lista_notas.filter(func(n): return n[2] >= duracao_nota):
		nota[0].queue_free()
	lista_notas = lista_notas.filter(func(n): return n[2] < duracao_nota)

# música de circo no cômodo dele: todo susto lá dentro fica mais forte por um tempo
func musica_de_circo() -> bool:
	comodo_musica = GameManager.fase.comodo_em(global_position)
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
	GameManager.fase.camera.tremer(5.0)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", escala_sprite * 1.3, 0.06)
	tween.tween_property(sprite, "scale", escala_sprite, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

static var textura_nota: ImageTexture

# nota musical branca de pixel, billboard, em cima do palhaço
func nova_nota() -> Sprite3D:
	if textura_nota == null:
		var desenho = [
			"....###.",
			"....#.##",
			"....#..#",
			"....#...",
			"....#...",
			"....#...",
			"..###...",
			".####...",
			".####...",
			"..##....",
		]
		var imagem = Image.create(8, 10, false, Image.FORMAT_RGBA8)
		for y in 10:
			for x in 8:
				if desenho[y][x] == "#":
					imagem.set_pixel(x, y, Color.WHITE)
		textura_nota = ImageTexture.create_from_image(imagem)
	var nota = Sprite3D.new()
	nota.texture = textura_nota
	nota.pixel_size = 0.04
	nota.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nota.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	nota.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	nota.shaded = false
	nota.modulate.a = 0.0
	notas.add_child(nota)
	return nota
