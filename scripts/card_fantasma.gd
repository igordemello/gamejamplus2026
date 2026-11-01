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
# o que segue o mouse enquanto arrasta; a área do jogo deixa avermelhado onde não pode soltar
var preview: Control
var tween_chacoalho: Tween
var tween_hover: Tween

func _ready() -> void:
	var fantasma: Fantasma = cena.instantiate()
	custo = fantasma.custo
	restantes = fantasma.usos
	comodo_spawn = fantasma.comodo_spawn
	comodos_proibidos = fantasma.comodos_proibidos
	pontos_spawn = fantasma.pontos_spawn
	fora_de_casa = fantasma.fora_de_casa

	var restricao = ""
	if comodo_spawn != "":
		restricao = "Só em: %s" % comodo_spawn
	elif fora_de_casa:
		restricao = "Só do lado de fora"
	elif pontos_spawn != &"":
		restricao = "Só nos pontos de %s" % pontos_spawn
	elif not comodos_proibidos.is_empty():
		restricao = "Não entra em %s" % ", ".join(comodos_proibidos)

	$linha/icone.texture = icone
	$linha/textos/nome.text = fantasma.name
	$linha/textos/restricao.text = restricao
	$linha/textos/restricao.visible = restricao != ""
	atualizar_custo()
	fantasma.free()
	mouse_entered.connect(crescer.bind(1.04))
	mouse_exited.connect(crescer.bind(1.0))

func _process(_delta: float) -> void:
	disabled = GameManager.sustos < custo or restantes <= 0
	modulate.a = 0.45 if disabled else 1.0

func comprou() -> void:
	GameManager.sustos -= custo
	restantes -= 1
	atualizar_custo()

func atualizar_custo() -> void:
	$linha/textos/custo.text = "%d sustos - %s %d" % [custo, "resta" if restantes == 1 else "restam", restantes]

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

# cresce um tiquinho com o mouse em cima
func crescer(tamanho: float) -> void:
	pivot_offset = size / 2.0
	if tween_hover:
		tween_hover.kill()
	tween_hover = create_tween().set_ignore_time_scale()
	tween_hover.tween_property(self, "scale", Vector2.ONE * tamanho, 0.1)

# chacoalha de lado quando tenta arrastar sem poder comprar
func chacoalhar() -> void:
	if tween_chacoalho and tween_chacoalho.is_running():
		return
	var x = position.x
	tween_chacoalho = create_tween()
	for desvio in [8.0, -8.0, 5.0, -3.0, 0.0]:
		tween_chacoalho.tween_property(self, "position:x", x + desvio, 0.04)
