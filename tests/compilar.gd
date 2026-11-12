extends SceneTree

# Compila os scripts e mostra os erros (o --check-only não carrega o GameManager e acusa erro falso).
#   godot --headless --path . --script res://tests/compilar.gd                 todos de scripts/
#   godot --headless --path . --script res://tests/compilar.gd -- ui/lore.gd   só esses (caminho dentro de scripts/)

func _initialize() -> void:
	call_deferred("compilar")

func compilar() -> void:
	# espera o autoload existir
	await process_frame
	var lista = Array(OS.get_cmdline_user_args()).map(func(a): return "res://scripts/" + a)
	if lista.is_empty():
		lista = todos("res://scripts")
	var ruins = 0
	for caminho in lista:
		var script = load(caminho)
		if script == null or not script.can_instantiate():
			ruins += 1
			print("ERRO: ", caminho)
	print("compilados: %d, com erro: %d" % [lista.size(), ruins])
	quit(1 if ruins > 0 else 0)

func todos(pasta: String) -> Array:
	var achados = []
	for arquivo in DirAccess.get_files_at(pasta):
		if arquivo.ends_with(".gd"):
			achados.append(pasta + "/" + arquivo)
	for sub in DirAccess.get_directories_at(pasta):
		achados += todos(pasta + "/" + sub)
	return achados
