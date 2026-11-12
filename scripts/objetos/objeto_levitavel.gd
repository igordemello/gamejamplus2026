# Prop 3D que levita enquanto o mouse segura e assusta quem está no mesmo cômodo.
extends Node3D

@export var altura_levitacao: float = 0.14
@export var velocidade_levitacao: float = 5.0
@export var intensidade_tremida: float = 0.023
@export var suavidade: float = 10.0
# segundos segurando até a tremida chegar no máximo
@export var tempo_carga: float = 1.5
# subidinha quando o mouse passa por cima, mostrando que dá pra pegar
@export var altura_hover: float = 0.045

@export var tipo_susto: String = "objeto"
@export var pontos_susto: int = 15
# a partir desse nível de medo o objeto quase não faz efeito: quem termina o serviço são os fantasmas
@export var nivel_fraco: int = 2
@export var pontos_susto_fraco: int = 3
@export var intervalo_susto: float = 1.0

@onready var malha: MeshInstance3D = $malha

var posicao_original: Vector3
var escala_original: Vector3
var tempo: float = 0.0
var segurando: bool = false
# o primeiro susto de cada vez que pega solta um "BUUU!"
var primeiro_susto: bool = false
var tempo_susto: float = 0.0
# 0..1, clareia o objeto: o tutorial pulsa isso; hover e flash do susto somam por cima (vale o maior)
var destaque: float = 0.0
var brilho_hover: float = 0.0
var brilho_susto: float = 0.0

var tween_escala: Tween
var tween_queda: Tween
var tween_brilho: Tween
var som_levitando: AudioStreamPlayer
var material: StandardMaterial3D

func _ready() -> void:
	add_to_group("levitavel")
	posicao_original = position
	escala_original = scale
	# cópia por objeto, senão o brilho de um acende todos
	material = malha.get_active_material(0).duplicate()
	material.emission_enabled = true
	material.emission = Color.WHITE
	malha.material_override = material

func _process(delta: float) -> void:
	var em_cima = mouse_em_cima()
	brilho_hover = move_toward(brilho_hover, 1.0 if segurando or em_cima else 0.0, delta * 8.0)
	material.emission_energy_multiplier = maxf(maxf(destaque, brilho_hover * 0.5), brilho_susto) * 0.8
	if segurando:
		tempo += delta
		# quanto mais tempo segurando, mais treme e balança
		var carga = minf(tempo / tempo_carga, 1.0)
		var alvo = posicao_original + Vector3.UP * (altura_levitacao + sin(tempo * velocidade_levitacao) * 0.035)
		var tremida = intensidade_tremida * (0.3 + carga)
		alvo += Vector3(randf_range(-tremida, tremida), randf_range(-tremida, tremida), randf_range(-tremida, tremida))
		position = position.lerp(alvo, minf(suavidade * delta, 1.0))
		rotation.z = sin(tempo * 9.0) * 0.12 * carga

		tempo_susto += delta
		if tempo_susto >= intervalo_susto:
			tempo_susto = 0.0
			aplicar_susto()
			pulsar()
	elif not (tween_queda and tween_queda.is_running()):
		var alvo = posicao_original + (Vector3.UP * altura_hover if em_cima else Vector3.ZERO)
		position = position.lerp(alvo, minf(suavidade * delta, 1.0))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and mouse_em_cima() and not GameManager.fase.mirando:
			levantar()
		elif not event.pressed and segurando:
			soltar()

func mouse_em_cima() -> bool:
	return GameManager.fase.mouse_em_malha(malha)

# ponto em cima do objeto (a seta do tutorial aponta pra cá)
func topo() -> Vector3:
	return malha.global_transform * malha.get_aabb().get_center() + Vector3.UP * malha.get_aabb().size.y * 0.5

func levantar() -> void:
	segurando = true
	primeiro_susto = true
	tempo = 0.0
	tempo_susto = 0.0
	if tween_queda:
		tween_queda.kill()
	som_levitando = GameManager.som.tocar("levitando")
	# estica pra cima no puxão
	esticar(Vector3(0.8, 1.25, 0.8))

# cai quicando e amassa quando bate no chão
func soltar() -> void:
	segurando = false
	GameManager.som.parar(som_levitando)
	tween_queda = create_tween()
	tween_queda.tween_property(self, "position", posicao_original, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween_queda.parallel().tween_property(self, "rotation", Vector3.ZERO, 0.2)
	# a primeira batida do TRANS_BOUNCE é em ~36% do tempo
	tween_queda.parallel().tween_callback(esticar.bind(Vector3(1.3, 0.75, 1.3))).set_delay(0.16)

# o diabrete pegou (o prop também está no grupo "quebravel"): larga o mouse, volta pro chão e
# para de levitar e de receber clique. quem pegou cuida do resto
func ser_pego() -> void:
	segurando = false
	GameManager.som.parar(som_levitando)
	remove_from_group("levitavel")
	for tween in [tween_queda, tween_escala, tween_brilho]:
		if tween:
			tween.kill()
	position = posicao_original
	scale = escala_original
	rotation = Vector3.ZERO
	brilho_hover = 0.0
	brilho_susto = 0.0
	material.emission_energy_multiplier = 0.0
	set_process(false)
	set_process_input(false)

func reaparecer() -> void:
	add_to_group("levitavel")
	set_process(true)
	set_process_input(true)

# a cada susto: incha, pisca claro e a tela dá uma tremidinha
func pulsar() -> void:
	esticar(Vector3(1.3, 1.3, 1.3))
	brilho_susto = 2.0
	if tween_brilho:
		tween_brilho.kill()
	tween_brilho = create_tween()
	tween_brilho.tween_property(self, "brilho_susto", 0.0, 0.25)
	GameManager.fase.camera.tremer(2.0)
	if primeiro_susto:
		primeiro_susto = false
		Onomatopeia.soltar("BUUU!", topo(), Color(0.8, 1, 1))
		GameManager.som.tocar("buu_levitavel")

# deforma rapidinho e volta pro tamanho normal com um pulinho
func esticar(forma: Vector3) -> void:
	if tween_escala:
		tween_escala.kill()
	tween_escala = create_tween()
	tween_escala.tween_property(self, "scale", escala_original * forma, 0.06)
	tween_escala.tween_property(self, "scale", escala_original, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# cômodo onde ele está (vazio no corredor)
func comodo() -> String:
	return GameManager.fase.comodo_em(global_position)

func aplicar_susto() -> void:
	var meu = comodo()
	if meu == "":
		return
	for npc in get_tree().get_nodes_in_group("npc"):
		# só quem está de fato dentro do cômodo do objeto (no corredor, fora de cômodo, não conta)
		if npc is Npc and GameManager.fase.comodo_em(npc.global_position) == meu:
			npc.tomar_susto(tipo_susto, pontos_susto if npc.nivel_medo < nivel_fraco else pontos_susto_fraco)
