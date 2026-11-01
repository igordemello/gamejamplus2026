extends Button

@export var cena: PackedScene
@export var icone: Texture2D

var custo: int = 0
# quantas vezes ainda dá pra comprar (começa no "usos" do fantasma)
var restantes: int = 0
var comodo_spawn: String = ""
var comodos_proibidos: Array[String] = []
var pontos_spawn: StringName = &""
var fora_de_casa: bool = false
# só libera na loja com esse tanto de infartos (GameManager.mortes)
var mortes_para_liberar: int = 0
var estava_travada: bool = false
var tipo: int = 0
var tier: int = 1
# o desenho do fantasma, pros pontos fixos mostrarem onde ele vai ficar
var silhueta: Texture2D
var silhueta_escala: Vector2
var silhueta_posicao: Vector2
var silhueta_offset: Vector2
# o que segue o mouse enquanto arrasta; a área do jogo deixa avermelhado onde não pode soltar
var preview: Control
var tween_chacoalho: Tween
var tween_liberou: Tween

func _ready() -> void:
	var fantasma: Fantasma = cena.instantiate()
	custo = fantasma.custo
	restantes = fantasma.usos
	comodo_spawn = fantasma.comodo_spawn
	comodos_proibidos = fantasma.comodos_proibidos
	pontos_spawn = fantasma.pontos_spawn
	fora_de_casa = fantasma.fora_de_casa
	mortes_para_liberar = fantasma.mortes_para_liberar
	tipo = fantasma.tipo
	tier = fantasma.tier
	var sprite: AnimatedSprite2D = fantasma.get_node("AnimatedSprite2D")
	silhueta = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	silhueta_escala = sprite.scale * fantasma.scale
	silhueta_posicao = sprite.position * fantasma.scale
	silhueta_offset = sprite.offset

	# o que cada texto pode ocupar, antes de mexer na fonte
	var area_nome = $nome.size
	var area_custo = $custo.size

	$arte.texture = icone
	# uma palavra por linha ("Geleia / Roxa")
	$nome.text = fantasma.name.replace(" ", "\n")
	caber($nome, area_nome, 32)
	# tipo e tier numa linha discreta logo abaixo do nome, de uma ou duas linhas
	$tipo.text = "%s · tier %d" % [Fantasma.NOME_TIPO[tipo], tier]
	$tipo.position.y = $nome.position.y + $nome.get_minimum_size().y - 6.0
	# nome de duas linhas: a arte desce pra não bater na linha do tipo
	$arte.offset_top = maxf($arte.offset_top, $tipo.position.y + $tipo.get_minimum_size().y)
	$custo.text = str(custo)
	caber($custo, area_custo, 40)
	atualizar_restantes()
	var textos = rodape()
	$rodape1.text = textos[0]
	$rodape2.text = textos[1]

	# uma linha por ação; com 3 cabem só com letras menores
	var acoes = fantasma.acoes
	var altura = 142.0 / maxi(acoes.size(), 2)
	for acao in acoes:
		criar_habilidade(acao, fantasma, altura, 19 if acoes.size() > 2 else 22, 40 if acoes.size() > 2 else 52)
	fantasma.free()

	# carta travada: escura, com o cadeado e o que falta pra liberar
	$trava/texto.text = "Libera com %d %s" % [mortes_para_liberar, "morte" if mortes_para_liberar == 1 else "mortes"]
	# logo abaixo da linha do tipo, que a trava escurece mas não esconde
	$trava/texto.position.y = $tipo.position.y + $tipo.get_minimum_size().y
	estava_travada = travada()
	$trava.visible = estava_travada

# diminui a fonte até o texto caber na área
func caber(label: Label, area: Vector2, minimo: int) -> void:
	var tamanho = label.get_theme_font_size("font_size")
	while tamanho > minimo:
		var preciso = label.get_minimum_size()
		if preciso.x <= area.x and preciso.y <= area.y:
			break
		tamanho -= 2
		label.add_theme_font_size_override("font_size", tamanho)

func inicial(texto: String) -> String:
	return texto.substr(0, 1).to_upper() + texto.substr(1)

# as duas linhas de baixo da carta, conforme onde o fantasma pode ser colocado
func rodape() -> Array[String]:
	if comodo_spawn != "":
		return ["Só pode ser spawnado em:", inicial(comodo_spawn)]
	if fora_de_casa:
		return ["Só pode ser spawnado:", "Do lado de fora"]
	if pontos_spawn != &"":
		return ["Só pode ser spawnado nos pontos de:", inicial(pontos_spawn)]
	if not comodos_proibidos.is_empty():
		return ["Não pode ser spawnado em:", ", ".join(comodos_proibidos.map(inicial))]
	return ["Pode ser spawnado:", "Em qualquer lugar"]

# resumo da ação à esquerda, medo à direita
func criar_habilidade(acao: Acao, fantasma: Fantasma, altura: float, fonte_resumo: int, fonte_medo: int) -> void:
	var linha = HBoxContainer.new()
	linha.custom_minimum_size.y = altura
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_theme_constant_override("separation", 8)

	var resumo = Label.new()
	resumo.text = acao.resumo
	resumo.autowrap_mode = TextServer.AUTOWRAP_WORD
	resumo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resumo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resumo.add_theme_font_size_override("font_size", fonte_resumo)
	linha.add_child(resumo)

	var medo = Label.new()
	medo.text = acao.texto_medo(fantasma)
	medo.custom_minimum_size.x = 64
	medo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	medo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	medo.add_theme_font_size_override("font_size", fonte_medo)
	linha.add_child(medo)

	$habilidades.add_child(linha)

func travada() -> bool:
	return GameManager.mortes < mortes_para_liberar

func _process(_delta: float) -> void:
	var trancada = travada()
	disabled = trancada or GameManager.sustos < custo or restantes <= 0
	# a travada não fica transparente (o escuro por cima já avisa e não deixa ver as outras cartas)
	modulate.a = 0.45 if disabled and not trancada else 1.0
	if trancada != estava_travada:
		$trava.visible = trancada
		if not trancada:
			liberou()
		estava_travada = trancada

# chegou nas mortes que faltavam: a carta brilha e a arte e o custo dão um pulinho
func liberou() -> void:
	if tween_liberou:
		tween_liberou.kill()
	if $brilho.material == null:
		$brilho.material = CanvasItemMaterial.new()
		$brilho.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	$brilho.show()
	$brilho.modulate.a = 0.0
	tween_liberou = create_tween().set_parallel().set_ignore_time_scale()
	for no in [$arte, $custo]:
		no.pivot_offset = no.size / 2.0
		no.scale = Vector2.ONE * 1.35
		tween_liberou.tween_property(no, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# duas piscadas
	var pisca = create_tween().set_ignore_time_scale()
	for i in 2:
		pisca.tween_property($brilho, "modulate:a", 0.8, 0.1)
		pisca.tween_property($brilho, "modulate:a", 0.0, 0.35)
	pisca.tween_callback($brilho.hide)

func comprou() -> void:
	GameManager.sustos -= custo
	restantes -= 1
	atualizar_restantes()

func atualizar_restantes() -> void:
	$restam.text = "%s %d" % ["resta" if restantes == 1 else "restam", restantes]

func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled:
		chacoalhar()
		return null

	# tamanho fixo, senão ícone recortado de sprite grande vem enorme;
	# o preview fica com o canto no mouse, então centraliza dentro de um Control
	var imagem = TextureRect.new()
	imagem.texture = icone
	imagem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	imagem.size = Vector2(72, 72)
	imagem.position = -imagem.size / 2
	preview = Control.new()
	preview.add_child(imagem)
	set_drag_preview(preview)
	return self

# chacoalha de lado quando tenta arrastar sem poder comprar
func chacoalhar() -> void:
	if tween_chacoalho and tween_chacoalho.is_running():
		return
	var x = position.x
	tween_chacoalho = create_tween()
	for desvio in [8.0, -8.0, 5.0, -3.0, 0.0]:
		tween_chacoalho.tween_property(self, "position:x", x + desvio, 0.04)
