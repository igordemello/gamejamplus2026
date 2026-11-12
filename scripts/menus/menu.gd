extends Control

func _ready() -> void:
	GameManager.som.tocar_musica("menu")

func _on_btn_play_button_down() -> void:
	get_tree().change_scene_to_file("res://scene/fases/casa/casa.tscn")

func _on_btn_config_button_down() -> void:
	$config.show()

func _on_btn_sair_button_down() -> void:
	get_tree().quit()

func _on_btn_credits_button_down() -> void:
	get_tree().change_scene_to_file("res://scene/menus/credito.tscn")
