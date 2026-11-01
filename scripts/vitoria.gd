extends CanvasLayer

# tela do fim: aparece quando não sobra ninguém na casa (House.terminar). vitória se cumpriu
# algum objetivo, senão "fim de festa"

@onready var fundo: ColorRect = $fundo
@onready var caixa: VBoxContainer = $caixa
@onready var titulo: Label = $caixa/titulo

func _ready() -> void:
	hide()
	%jogar_de_novo.pressed.connect(_on_jogar_de_novo)
	%menu.pressed.connect(_on_menu)

# o Esc da pausa não vale aqui
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func mostrar(fugiram: int, mortes: int, tempo: float, venceu: bool) -> void:
	titulo.text = "Vitória!" if venceu else "Fim de festa"
	$caixa/subtitulo.text = "A casa esvaziou e você cumpriu um objetivo." if venceu else "A casa esvaziou, mas nenhum objetivo foi cumprido."
	%jogar_de_novo.text = "Jogar de novo" if venceu else "Tentar de novo"
	%fugiram.text = "%d fugiram da casa" % fugiram
	%mortes.text = "%d morreram de susto" % mortes
	%tempo.text = "Tempo: %d:%02d" % [int(tempo) / 60, int(tempo) % 60]
	get_tree().paused = true
	GameManager.tempo_normal()
	if venceu:
		GameManager.som.tocar_ui("vitoria")
	show()
	fundo.modulate.a = 0.0
	caixa.modulate.a = 0.0
	titulo.pivot_offset = titulo.size / 2.0
	titulo.scale = Vector2(2.5, 2.5)
	var tween = create_tween()
	tween.tween_property(fundo, "modulate:a", 1.0, 0.6)
	tween.tween_property(caixa, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(titulo, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_jogar_de_novo() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/menu.tscn")
