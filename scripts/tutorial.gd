extends CanvasLayer

# tutorial do começo: passos curtos num painel embaixo, com o jogo rodando atrás.
# os passos com "feito" passam sozinhos quando o jogador faz o que foi pedido.
# a casa só chama comecar() na primeira vez (fica salvo no config.cfg); a pausa tem "Como jogar"

const ARQUIVO = "user://config.cfg"

@onready var titulo: Label = %titulo
@onready var texto: Label = %texto
@onready var proximo: Button = %proximo

var house
var passos: Array = []
var atual: int = 0
var tempo: float = 0.0
# o que fica piscando pra chamar atenção no passo atual
var destaque: CanvasItem
# como estava quando o passo começou, pra saber se o jogador já fez
var zoom_inicial: float
var arrastado_inicial: float
var fantasmas_inicial: int
var concluido: bool = false

func _ready() -> void:
	hide()
	%pular.pressed.connect(terminar)
	proximo.pressed.connect(avancar)

static func ja_viu() -> bool:
	var cfg = ConfigFile.new()
	return cfg.load(ARQUIVO) == OK and cfg.get_value("jogo", "tutorial_visto", false)

func comecar(casa) -> void:
	house = casa
	var cam = house.camera
	passos = [
		{"titulo": "Bem-vindo, fantasma", "texto": "A casa está cheia de gente em festa. Seu trabalho é assustar todo mundo até a casa ficar vazia."},
		{"titulo": "Zoom", "texto": "Role a rodinha do mouse para aproximar ou afastar a câmera.",
			"feito": func(): return absf(cam.zoom_alvo - zoom_inicial) > 0.01},
		{"titulo": "Andar pela casa", "texto": "Com a câmera aproximada, segure o botão direito do mouse e arraste para andar pela casa.",
			"feito": func(): return cam.arrastado - arrastado_inicial > 150.0},
		{"titulo": "Chamar fantasmas", "texto": "Arraste um fantasma da loja, à direita, até a casa. Cada um custa sustos, e alguns só podem ficar em certos lugares (está escrito no card).",
			"destaque": house.ui.get_node("painel_fantasmas"),
			"feito": func(): return get_tree().get_nodes_in_group("fantasma").size() > fantasmas_inicial},
		{"titulo": "Usar ações", "texto": "Segure o botão esquerdo em cima de um fantasma: o tempo desacelera e aparecem as ações dele. Arraste até uma e solte. Cada ação tem recarga.",
			"feito": func(): return get_tree().get_nodes_in_group("fantasma").any(func(f): return f.recarga_restante.values().any(func(r): return r > 0.0))},
		{"titulo": "Objetos", "texto": "Alguns objetos da casa flutuam: segure o botão esquerdo em cima de um para ele levitar e assustar quem estiver no mesmo cômodo."},
		{"titulo": "Medo", "texto": "Cada susto enche a barrinha em cima da pessoa. Barra cheia: ela sobe um nível de medo e você ganha 1 susto. No nível 5 ela foge da casa.",
			"destaque": house.ui.get_node("contadores/sustos")},
		{"titulo": "Infarto", "texto": "Cada tipo de pessoa tem um fantasma que mata ela do coração (o tipo e o tier certos). Infarto vale 3 sustos e conta como morte. Passe o mouse nos contadores para lembrar.",
			"destaque": house.ui.get_node("contadores/mortes")},
		{"titulo": "Pronto!", "texto": "Esc pausa o jogo, e na pausa dá para ver este tutorial de novo. Boa assombração!"},
	]
	atual = -1
	show()
	avancar()

func avancar() -> void:
	if destaque:
		destaque.modulate = Color.WHITE
	atual += 1
	if atual >= passos.size():
		terminar()
		return
	var passo = passos[atual]
	titulo.text = "%s   (%d/%d)" % [passo.titulo, atual + 1, passos.size()]
	texto.text = passo.texto
	proximo.text = "Começar" if atual == passos.size() - 1 else "Próximo"
	destaque = passo.get("destaque")
	concluido = false
	zoom_inicial = house.camera.zoom_alvo
	arrastado_inicial = house.camera.arrastado
	fantasmas_inicial = get_tree().get_nodes_in_group("fantasma").size()

func _process(delta: float) -> void:
	if atual < 0 or atual >= passos.size():
		return
	tempo += delta
	if destaque:
		destaque.modulate = Color.WHITE.lerp(Color(1.8, 1.8, 1.8), 0.5 + 0.5 * sin(tempo * 6.0))
	var feito = passos[atual].get("feito")
	if feito and not concluido and feito.call():
		# fez o que o passo pedia: mostra que deu certo e passa sozinho
		concluido = true
		proximo.text = "Boa!"
		var passo_agora = atual
		get_tree().create_timer(0.9).timeout.connect(func():
			if atual == passo_agora:
				avancar())

func terminar() -> void:
	if destaque:
		destaque.modulate = Color.WHITE
	destaque = null
	atual = passos.size()
	hide()
	var cfg = ConfigFile.new()
	cfg.load(ARQUIVO)
	cfg.set_value("jogo", "tutorial_visto", true)
	cfg.save(ARQUIVO)
