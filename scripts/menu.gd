extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.som.tocar_musica("menu")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_btn_play_button_down() -> void:
	get_tree().change_scene_to_file("res://scene/house.tscn")


func _on_btn_config_button_down() -> void:
	$config.show()


func _on_btn_sair_button_down() -> void:
	get_tree().quit()
