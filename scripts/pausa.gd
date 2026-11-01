extends CanvasLayer

@onready var botoes: VBoxContainer = %botoes
@onready var config: Config = %config

func _ready() -> void:
	hide()
	config.voltar.connect(botoes.show)
	%continuar.pressed.connect(despausar)
	%como_jogar.pressed.connect(_on_como_jogar)
	%configuracoes.pressed.connect(_on_configuracoes)
	%menu.pressed.connect(_on_menu)
	%sair.pressed.connect(get_tree().quit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			despausar()
		else:
			pausar()
		get_viewport().set_input_as_handled()

func pausar() -> void:
	get_tree().paused = true
	botoes.show()
	config.hide()
	show()

func despausar() -> void:
	get_tree().paused = false
	hide()

func _on_como_jogar() -> void:
	despausar()
	GameManager.house.tutorial.comecar(GameManager.house)

func _on_configuracoes() -> void:
	botoes.hide()
	config.show()

func _on_menu() -> void:
	despausar()
	# se pausou segurando um fantasma, o menu de ações deixou o jogo em câmera lenta
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scene/menu.tscn")
