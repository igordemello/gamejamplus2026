extends CanvasLayer

@onready var lbl_sustos: Label = $lbl_sustos

var sustos_antes: int = 0
var tween_sustos: Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sustos_antes = GameManager.sustos


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if GameManager.sustos != sustos_antes:
		# cresce quando ganha, encolhe quando gasta
		pular_contador(1.4 if GameManager.sustos > sustos_antes else 0.8)
		sustos_antes = GameManager.sustos
	lbl_sustos.text = "Sustos: " + str(GameManager.sustos)

func pular_contador(tamanho: float) -> void:
	if tween_sustos:
		tween_sustos.kill()
	tween_sustos = create_tween()
	tween_sustos.tween_property(lbl_sustos, "scale", Vector2.ONE * tamanho, 0.06)
	tween_sustos.tween_property(lbl_sustos, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
