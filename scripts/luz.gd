extends PointLight2D

# luz da casa. tremula (vela, lareira), pode ter defeito (lâmpada do banheiro),
# pisca quando tem susto perto (House.piscar_luzes) e, com cores, vira luz de festa:
# troca de cor e pulsa a cada batida e anda em círculo em volta de onde foi colocada

# 0 = firme, 1 = fogo
@export var tremor: float = 0.1
@export var velocidade_tremor: float = 1.0
# chance por segundo de apagar um instante
@export var falha: float = 0.0
@export var cores: Array[Color] = []
@export var bpm: float = 0.0
# a pista: elipse em volta da posição inicial (y achatado, a câmera é de cima)
@export var raio_orbita: float = 0.0
@export var velocidade_orbita: float = 0.5
@export var fase: float = 0.0

var energia_base: float
var centro: Vector2
var tempo: float = 0.0
var ruido := FastNoiseLite.new()
var tempo_piscando: float = 0.0
var tempo_apagada: float = 0.0

func _ready() -> void:
	add_to_group("luz")
	energia_base = energy
	centro = position
	ruido.seed = randi()
	ruido.frequency = 0.5

func _process(delta: float) -> void:
	tempo += delta
	var e = energia_base * (1.0 + ruido.get_noise_1d(tempo * velocidade_tremor * 20.0) * tremor)

	if not cores.is_empty() and bpm > 0.0:
		var batida = tempo * bpm / 60.0
		color = cores[(int(batida) + int(fase * cores.size())) % cores.size()]
		# acende forte na batida e vai caindo
		e *= 0.55 + 0.6 * pow(1.0 - fmod(batida, 1.0), 2.0)
	if raio_orbita > 0.0:
		var angulo = tempo * velocidade_orbita * TAU + fase * TAU
		position = centro + Vector2(cos(angulo), sin(angulo) * 0.55) * raio_orbita

	if tempo_apagada > 0.0:
		tempo_apagada -= delta
		e *= 0.08
	elif randf() < falha * delta:
		tempo_apagada = randf_range(0.04, 0.25)

	# susto por perto: pisca sem ritmo
	if tempo_piscando > 0.0:
		tempo_piscando -= delta
		if sin(tempo * 41.0) + sin(tempo * 27.0) > 0.4:
			e *= 0.1
	energy = e

func piscar(duracao: float) -> void:
	tempo_piscando = maxf(tempo_piscando, duracao)
