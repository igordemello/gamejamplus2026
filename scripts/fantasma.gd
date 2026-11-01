extends Node2D
class_name Fantasma

const CONTORNO = preload("res://assets/contorno.tres")

enum Tipo {
	Aparicao,
	Poltergeist,
	Espectro,
	Demonio
}

const NOME_TIPO = {
	Tipo.Aparicao: "Aparição",
	Tipo.Poltergeist: "Poltergeist",
	Tipo.Espectro: "Espectro",
	Tipo.Demonio: "Demônio"
}

@export var custo: int = 5
@export var tier: int = 1
@export var tipo: Tipo = Tipo.Aparicao
# quantas vezes dá pra comprar esse fantasma na loja
@export var usos: int = 5

# nome do nó do cômodo em houseRegions onde pode ser colocado, vazio = qualquer lugar
@export var comodo_spawn: String = ""
@export var comodos_proibidos: Array[String] = []
# se preenchido, só pode ser colocado num ponto livre desse grupo (ex.: "armadura")
@export var pontos_spawn: StringName = &""

@export var acoes: Array[Acao] = []
@export var raio_clique: float = 32.0

var recarga_restante: Dictionary = {}
var selecionado: bool = false
# cópia por fantasma, senão o brilho de um acende todos
var material_fantasma: ShaderMaterial = CONTORNO.duplicate()
var escala_sprite: Vector2 = Vector2.ZERO
var tween_pulinho: Tween
var tween_negar: Tween

func _enter_tree() -> void:
	add_to_group("fantasma")

func _process(delta: float) -> void:
	for acao in recarga_restante:
		var antes = recarga_restante[acao]
		recarga_restante[acao] = maxf(antes - delta, 0.0)
		# piscadinha avisando que a ação ficou pronta de novo
		if antes > 0.0 and recarga_restante[acao] == 0.0:
			piscar(1, 0.08)

	$AnimatedSprite2D.material = material_fantasma
	material_fantasma.set_shader_parameter("contorno", selecionado or mouse_em_cima())

# fica branco rapidinho algumas vezes
func piscar(vezes: int, duracao: float) -> void:
	var tween = create_tween()
	for i in vezes:
		tween.tween_callback(material_fantasma.set_shader_parameter.bind("brilho", 1.0))
		tween.tween_interval(duracao)
		tween.tween_callback(material_fantasma.set_shader_parameter.bind("brilho", 0.0))
		tween.tween_interval(duracao)

# mede do meio do desenho, porque alguns fantasmas têm a origem nos pés
func mouse_em_cima() -> bool:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	var centro = sprite.global_position + sprite.offset * sprite.global_scale
	return centro.distance_to(get_global_mouse_position()) <= raio_clique

func executar(acao: Acao) -> void:
	if recarga_restante.get(acao, 0.0) <= 0.0 and call(acao.metodo):
		recarga_restante[acao] = acao.recarga
		pulinho()
	else:
		negar()

# chamado quando é solto da loja: cresce com um pulinho e aparece
func aparecer() -> void:
	var escala = scale
	scale = escala * 0.3
	modulate.a = 0.0
	var tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", escala, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)

# amassa e estica rapidinho quando usa uma ação
func pulinho() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	if escala_sprite == Vector2.ZERO:
		escala_sprite = sprite.scale
	if tween_pulinho:
		tween_pulinho.kill()
	tween_pulinho = create_tween()
	tween_pulinho.tween_property(sprite, "scale", escala_sprite * Vector2(1.25, 0.8), 0.06)
	tween_pulinho.tween_property(sprite, "scale", escala_sprite, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# balança a cabeça que não quando a ação não deu (recarregando ou ninguém perto)
func negar() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	# o offset é em pixels da arte; assim dá uns 5 px na tela em qualquer escala
	var passo = 5.0 / sprite.global_scale.x
	if tween_negar:
		tween_negar.kill()
	tween_negar = create_tween()
	for x in [passo, -passo, passo * 0.5, 0.0]:
		tween_negar.tween_property(sprite, "offset:x", x, 0.05)

func npc_mais_perto() -> Npc:
	var meu_comodo = GameManager.house.comodo_em(global_position)
	var mais_perto: Npc = null

	for npc in get_tree().get_nodes_in_group("npc"):
		if GameManager.house.comodo_em(npc.global_position) != meu_comodo:
			continue
		if mais_perto == null or global_position.distance_to(npc.global_position) < global_position.distance_to(mais_perto.global_position):
			mais_perto = npc

	return mais_perto
