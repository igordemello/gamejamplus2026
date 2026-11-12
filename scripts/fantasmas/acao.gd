extends Resource
class_name Acao

@export var nome: String = ""
@export var icone: Texture2D
@export_multiline var descricao: String = ""
@export var recarga: float = 5.0
# função do fantasma chamada quando solta em cima da ação, devolve false se não deu pra fazer
@export var metodo: StringName
# texto curto da ação na carta da loja
@export var resumo: String = ""
# nome da variável do fantasma que guarda o medo dessa ação (vazio = não mostra)
@export var propriedade_medo: StringName
# escolhe o lugar no mapa antes de acontecer: o método recebe a posição
@export var mira: bool = false
# susto em área: quanto mais gente pegar, mais forte fica (Fantasma.medo_em_grupo)
@export var em_grupo: bool = false

# o medo da ação lido do fantasma: "18", "x1.5" (multiplicador) ou "-" se não tiver
func texto_medo(fantasma: Object) -> String:
	if propriedade_medo == &"":
		return "-"
	var valor = fantasma.get(propriedade_medo)
	return "x%s" % valor if valor is float else str(valor)
