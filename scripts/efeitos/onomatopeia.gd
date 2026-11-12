extends Node2D
class_name Onomatopeia

# onomatopeia de quadrinho ("NHAC!", "CRASH!") numa fonte pixel 5x7 desenhada aqui mesmo,
# quadradinho por quadradinho. pula, sobe e some. Onomatopeia.soltar("POW!", pos, cor)

const LETRAS = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
	"-": [".....", ".....", ".....", ".###.", ".....", ".....", "....."],
}

var texto: String = ""
var cor: Color = Color.WHITE
# tamanho de cada pixel da fonte, em px de tela com o zoom em 1
var pixel: float = 3.0
# ponto do mundo onde ela nasceu; o pulo e a subida são em px de tela
var pos: Vector3
var sobe: float = 0.0
var forma: float = 0.3

static func soltar(palavra: String, onde: Vector3, cor_texto: Color, tamanho: float = 3.0) -> void:
	var fase = GameManager.fase
	if fase == null:
		return
	var o = Onomatopeia.new()
	o.texto = palavra.to_upper()
	o.cor = cor_texto
	o.pixel = tamanho
	o.pos = onde
	o.z_index = 3
	fase.mundo.add_child(o)

func _ready() -> void:
	rotation = randf_range(-0.2, 0.2)
	var tween = create_tween()
	tween.tween_property(self, "forma", 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "forma", 1.0, 0.08)
	tween.parallel().tween_property(self, "sobe", 40.0, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.9)
	tween.tween_callback(queue_free)
	_process(0.0)

func _process(_delta: float) -> void:
	var fase = GameManager.fase
	var zoom = fase.pixels_por_metro(pos) / 88.0
	fase.posicionar(self, pos)
	position.y -= sobe * zoom
	scale = Vector2.ONE * forma * zoom

func largura() -> float:
	return (texto.length() * 6 - 1) * pixel

func _draw() -> void:
	var sombra = cor.darkened(0.6)
	var inicio = Vector2(-largura() / 2.0, -3.5 * pixel)
	for camada in [[Vector2(pixel, pixel), sombra], [Vector2.ZERO, cor]]:
		var x = 0.0
		for letra in texto:
			var desenho = LETRAS.get(letra)
			if desenho:
				for linha in 7:
					for coluna in 5:
						if desenho[linha][coluna] == "#":
							draw_rect(Rect2(inicio + camada[0] + Vector2(x + coluna * pixel, linha * pixel), Vector2(pixel, pixel)), camada[1])
			x += 6 * pixel
