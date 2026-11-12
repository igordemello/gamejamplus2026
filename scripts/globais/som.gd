extends Node

# todos os sons do jogo. o GameManager cria esse nó: GameManager.som.tocar("cao_latido")
# os volumes acertam a diferença de altura entre os arquivos. as ações dos fantasmas ficam baixas de propósito

const PASTA = "res://assets/sons/"

# nome: [arquivo, volume em dB]
const MUSICAS = {
	"menu": ["MUSICA/Resident Haunter - Menu.mp3", 0.0],
	"jogo": ["MUSICA/Resident Haunter - Musica normal gameplay.mp3", -7.0],
}

# nome: [arquivo, volume em dB, de onde começa (alguns arquivos abrem com silêncio)]
const SONS = {
	# ações dos fantasmas
	"morcego": ["morcego flap flap.mp3", -15.0, 1.25],
	"cavaleiro": ["cavaleiro shing.mp3", -15.0, 0.05],
	"crianca": ["criança buaaa.mp3", -3.0, 0.17],
	"diabrete_quebra": ["diabrete quebrando.mp3", -2.0, 0.03],
	"geleia_nhac": ["geleia nhac.mp3", -3.0, 0.0],
	"geleia_regurgitar": ["geleia regurgitar.mp3", -12.0, 0.26],
	"cao_latido": ["cao latido.mp3", -18.0, 0.13],
	"cao_nhac": ["cao nhac nhac.mp3", -5.0, 0.11],
	"zumbi_bafo": ["zumbi bafo.mp3", 6.0, 0.12],
	"zumbi_scratch": ["zumbi scratch.mp3", -16.0, 0.04],
	"caveira_risada": ["caveira ahhaha.mp3", -18.0, 0.0],
	"caveira_mordida": ["caveira mordida.mp3", -14.0, 0.45],
	"caveira_pow": ["caveira pow.mp3", -13.0, 0.08],
	"musica_palhaco": ["musica palhaço.mp3", -1.0, 0.7],
	"balao_inflando": ["palhaço balao inflando.mp3", -6.0, 0.22],
	"balao_estourando": ["palhaço balao estourando.mp3", -22.0, 0.03],
	# invocação e objeto levitável
	"ritual": ["invocação ritual.mp3", 4.0, 0.14],
	"vush": ["vush invocação.mp3", -11.0, 0.0],
	"buu_invocacao": ["buu de invocação.mp3", -12.0, 0.39],
	"levitando": ["objeto levitado (sme loop).mp3", -18.0, 0.0],
	"buu_levitavel": ["buu de levitavel.mp3", -16.0, 0.45],
	# npcs e casa
	"susto1": ["sustos/susto1.mp3", -4.0, 0.0],
	"susto2": ["sustos/susto2.mp3", -2.0, 0.0],
	"susto3": ["sustos/susto3.mp3", -4.0, 0.0],
	"susto4": ["sustos/susto4.mp3", -4.0, 0.0],
	"susto5": ["sustos/susto5.mp3", -4.0, 0.0],
	"susto6": ["sustos/susto6.mp3", -1.0, 0.0],
	"socorro": ["socorro indo embora fugindo.mp3", -9.0, 0.23],
	"infarto": ["infarto.mp3", 0.0, 0.06],
	"sirene": ["policia sirene.mp3", 0.0, 0.0],
	# interface
	"hover_ui": ["hover generico de ui.mp3", 2.0, 0.0],
	"hover_carta": ["hover cartas.mp3", -3.0, 0.0],
	"carta_pegar": ["carta pegar.mp3", -4.0, 0.2],
	"carta_liberada": ["desbloquear carta.mp3", -2.0, 0.21],
	"objetivo": ["objetivo concluido.mp3", -4.0, 0.0],
	"vitoria": ["som vitoria.mp3", -5.0, 0.04],
}

const SUSTOS = ["susto1", "susto2", "susto3", "susto4", "susto5", "susto6"]
# o mesmo som não toca mais que isso junto, nem duas vezes no mesmo instante (bafo em 8 npcs, duas cartas liberando)
const MAX_JUNTOS = 2
const INTERVALO_MINIMO = 60
# gritos diferentes também não saem todos de uma vez
const INTERVALO_GRITOS = 250
const FADE_MUSICA = 0.8

var musica_atual: AudioStreamPlayer
var nome_musica: String = ""
var ativos: Dictionary = {}
var ultima_vez: Dictionary = {}
var ultimo_susto: String = ""
var ultimo_grito: int = -INTERVALO_GRITOS

func _ready() -> void:
	# a música e os sons de interface tocam com o jogo pausado e continuam na troca de cena
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)

# som do mundo: fica na cena, então pausa com o jogo e some na troca de cena.
# com duracao, para sozinho nesse tempo, sumindo nos últimos segundos (fade)
func tocar(nome: String, duracao: float = 0.0, fade: float = 0.2) -> AudioStreamPlayer:
	var cena = get_tree().current_scene
	return criar(nome, cena if cena else self, duracao, fade)

func tocar_ui(nome: String) -> AudioStreamPlayer:
	return criar(nome, self, 0.0, 0.0)

# um dos sustos, nunca o mesmo duas vezes seguidas
func gritar() -> void:
	var agora = Time.get_ticks_msec()
	if agora - ultimo_grito < INTERVALO_GRITOS:
		return
	ultimo_grito = agora
	ultimo_susto = SUSTOS.filter(func(nome): return nome != ultimo_susto).pick_random()
	tocar(ultimo_susto)

# some rapidinho e libera o player. sem tipo no parâmetro: o som pode já ter acabado sozinho,
# e um objeto liberado num parâmetro tipado dá erro antes de chegar no is_instance_valid
func parar(player, fade: float = 0.1) -> void:
	if not is_instance_valid(player):
		return
	var tween = player.create_tween().set_ignore_time_scale()
	tween.tween_property(player, "volume_linear", 0.001, fade)
	tween.tween_callback(player.queue_free)

# põe o som num player que já está na cena (a música do palhaço, posicional); devolve de onde começar
func preparar(player: Node, nome: String) -> float:
	player.stream = load(PASTA + SONS[nome][0])
	player.volume_db = SONS[nome][1]
	return SONS[nome][2]

# troca a música com um fade; se já está tocando essa (Jogar de novo), segue sem recomeçar
func tocar_musica(nome: String) -> void:
	if nome == nome_musica:
		return
	nome_musica = nome
	if musica_atual:
		var antiga = musica_atual
		var sai = antiga.create_tween().set_ignore_time_scale()
		sai.tween_property(antiga, "volume_linear", 0.001, FADE_MUSICA)
		sai.tween_callback(antiga.queue_free)
	var stream: AudioStream = load(PASTA + MUSICAS[nome][0])
	# arquivo com a importação quebrada: fica sem música, mas o jogo segue
	if stream == null:
		push_warning("Música não carregou: " + MUSICAS[nome][0])
		musica_atual = null
		return
	stream.loop = true
	musica_atual = AudioStreamPlayer.new()
	musica_atual.stream = stream
	add_child(musica_atual)
	var volume = db_to_linear(MUSICAS[nome][1])
	musica_atual.volume_linear = 0.001
	musica_atual.play()
	musica_atual.create_tween().set_ignore_time_scale().tween_property(musica_atual, "volume_linear", volume, FADE_MUSICA)

func criar(nome: String, pai: Node, duracao: float, fade: float) -> AudioStreamPlayer:
	var agora = Time.get_ticks_msec()
	if ativos.get(nome, 0) >= MAX_JUNTOS or agora - ultima_vez.get(nome, -INTERVALO_MINIMO) < INTERVALO_MINIMO:
		return null
	ultima_vez[nome] = agora
	var stream: AudioStream = load(PASTA + SONS[nome][0])
	if stream == null:
		push_warning("Som não carregou: " + SONS[nome][0])
		return null
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SONS[nome][1]
	player.finished.connect(player.queue_free)
	ativos[nome] = ativos.get(nome, 0) + 1
	player.tree_exited.connect(func(): ativos[nome] -= 1)
	pai.add_child(player)
	player.play(SONS[nome][2])
	if duracao > 0.0:
		# em tempo real: o áudio não desacelera na câmera lenta
		var tween = player.create_tween().set_ignore_time_scale()
		tween.tween_interval(maxf(duracao - fade, 0.0))
		tween.tween_property(player, "volume_linear", 0.001, fade)
		tween.tween_callback(player.queue_free)
	return player

# todo botão do jogo toca o hover. as cartas são botões flat e têm som próprio (baralho.gd)
func _on_node_added(node: Node) -> void:
	if node is Button and not node.flat:
		node.mouse_entered.connect(func():
			if not node.disabled:
				tocar_ui("hover_ui"))
