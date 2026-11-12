extends RefCounted

# Vista 2.5D: a lógica do jogo continua toda em 2D (x, y de tela), e a casa é desenhada em 3D.
# A câmera 3D é ortográfica, inclinada ANGULO graus pra baixo e sem girar de lado: com o mundo 3D
# esticado em z por 1/SEN, o chão 3D cai na tela exatamente onde o 2D desenharia. Por isso mouse,
# hover, medidor, onomatopeias e o resto da UI continuam valendo sem mudar nada.
#   chão 2D (x, y)                      -> 3D (x, 0, y / SEN)
#   h pixels de tela acima do chão      -> 3D y = h / COS
# Use com preload (sem class_name, por causa dos testes headless).

const ANGULO := 50.0
# altura das paredes da arte 2D, em pixels de tela (a face marrom das paredes tem 64 px)
const ALTURA_PAREDE := 64.0
# camada de visibilidade 2D que a viewport não desenha: quem tem desenho 3D vai pra ela
const CAMADA_OCULTA := 1 << 19

static var SEN: float = sin(deg_to_rad(ANGULO))
static var COS: float = cos(deg_to_rad(ANGULO))

# ponto do chão 2D (com altura em pixels de tela) no mundo 3D
static func chao(p: Vector2, altura: float = 0.0) -> Vector3:
	return Vector3(p.x, altura / COS, p.y / SEN)

# onde um ponto 3D aparece no mundo 2D (o mesmo ponto de tela)
static func para_2d(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z * SEN - v.y * COS)

# o item 2D continua existindo (lógica, hover, filhos), só não é desenhado na vista 2.5D
static func esconder(item: CanvasItem) -> void:
	item.visibility_layer = CAMADA_OCULTA

# ponto 2D de um desenho em pé (billboard) no mundo 3D: a âncora é o ponto do chão (o pé); o que está
# acima dela na tela vai por cima (vetor 3D por pixel 2D) e o que está do lado vai por direita.
# escala aumenta o desenho em volta do pé. O padrão (RIGHT, UP / COS) é o plano em pé sem giro.
static func em_pe(p: Vector2, ancora: Vector2, direita: Vector3 = Vector3.RIGHT, cima: Vector3 = Vector3.UP / COS, escala: float = 1.0) -> Vector3:
	return chao(ancora) + (direita * (p.x - ancora.x) + cima * (ancora.y - p.y)) * escala

# transform de um quad unitário (0..1 em x e y, y pra baixo) que cobre o retângulo r (local do item 2D),
# no plano direita x cima, preso na âncora. Com direita/cima da câmera é um billboard de frente pra ela
static func quad(g: Transform2D, r: Rect2, ancora: Vector2, direita: Vector3 = Vector3.RIGHT, cima: Vector3 = Vector3.UP / COS, escala: float = 1.0) -> Transform3D:
	var ex = g.basis_xform(Vector2(r.size.x, 0.0)) * escala
	var ey = g.basis_xform(Vector2(0.0, r.size.y)) * escala
	var b = Basis(direita * ex.x - cima * ex.y, direita * ey.x - cima * ey.y, direita.cross(cima).normalized())
	return Transform3D(b, em_pe(g * r.position, ancora, direita, cima, escala))
