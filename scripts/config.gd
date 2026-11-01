extends Control
class_name Config

signal voltar

const ARQUIVO = "user://config.cfg"

@onready var volume: HSlider = %volume
@onready var tela_cheia: CheckButton = %tela_cheia

func _ready() -> void:
	volume.value = db_to_linear(AudioServer.get_bus_volume_db(0)) * 100
	tela_cheia.button_pressed = DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
	# conecta depois de preencher pra não salvar só de abrir
	volume.value_changed.connect(salvar.unbind(1))
	tela_cheia.toggled.connect(salvar.unbind(1))
	%voltar.pressed.connect(_on_voltar)

func _on_voltar() -> void:
	hide()
	voltar.emit()

func salvar() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("config", "volume", volume.value / 100.0)
	cfg.set_value("config", "tela_cheia", tela_cheia.button_pressed)
	cfg.save(ARQUIVO)
	aplicar(cfg)

# chamado pelo GameManager quando o jogo abre
static func carregar() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(ARQUIVO) == OK:
		aplicar(cfg)

static func aplicar(cfg: ConfigFile) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(cfg.get_value("config", "volume", 1.0)))
	var modo = DisplayServer.WINDOW_MODE_FULLSCREEN if cfg.get_value("config", "tela_cheia", true) else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != modo:
		DisplayServer.window_set_mode(modo)
