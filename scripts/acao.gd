extends Resource
class_name Acao

@export var nome: String = ""
@export var icone: Texture2D
@export_multiline var descricao: String = ""
@export var recarga: float = 5.0
# função do fantasma chamada quando solta em cima da ação, devolve false se não deu pra fazer
@export var metodo: StringName
