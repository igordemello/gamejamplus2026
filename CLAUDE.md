# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Responda sempre em português.**

## Visão geral

Resident Haunter é um jogo em Godot 4.7 (GDScript, renderer Forward Plus, D3D12 no Windows, física Jolt). O jogador é um fantasma que assusta NPCs que andam por uma casa, levitando objetos com o mouse e invocando outros fantasmas. Não há sistema de build, testes automáticos de CI nem linter: tudo roda pelo editor do Godot.

O jogo é 3D de verdade, estilo Octopath: o mundo é 3D (em metros, y pra cima, chão em y = 0) e os personagens são sprites 2D em pé dentro dele. Posição, navegação, colisão, cliques (raio da câmera) e efeitos são 3D. Só a UI (`CanvasLayer`: HUD, cartas, menus, pausa) é 2D. Os números antigos em pixels foram convertidos com **1 m = 88 px**: o convidado tem ~1,75 m, a casa ~19 m de largura, as paredes 1,2 m. Raio, velocidade e aceleração citados aqui estão em metros (e m/s).

## Comandos

O Godot não está no PATH. Ele está instalado via Steam em `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe` (4.7.2). No editor, F5 roda a cena principal e F6 a cena atual. Pela linha de comando (troque `godot` pelo caminho acima):

```bash
godot --path . -e
```

```bash
godot --path .
```

```bash
godot --path . scene/fases/casa/casa.tscn
```

O primeiro abre o editor, o segundo roda a partir do menu, o terceiro roda direto a fase da casa (pula o menu).

### Testes e scripts de verificação

Ficam em `tests/`. Todos rodam sem o editor:

- `verificar_partida.gd`: joga uma partida inteira sem mouse.
- `verificar_npcs.gd`: confere os 9 convidados únicos, os recortes dos sprites, as 30 frases de lore, as 90 combinações de infarto (10 NPCs × 9 fantasmas) e a chegada única do policial no limite de mortes.
- `verificar_reaparecimento.gd`: dois ciclos de quebra e retorno (após 30 s) de um objeto quebrável comum e de um levitável segurado pelo mouse, com transformação, grupos e reativação da interação.
- `verificar_alvo_tutorial.gd`: a seta do tutorial.
- `compilar.gd`: compila os scripts já com o autoload carregado. O `--check-only` não carrega o `GameManager` e acusa erro falso. Sem argumentos compila tudo de `scripts/`; com `-- ui/lore.gd` só os citados (caminho dentro de `scripts/`).
- `print_casa.gd`: print com janela (`--windowed --resolution 1920x1080`). Opções: `saida=`, `espera=`, `x=`/`z=` (ponto que a câmera olha), `zoom=`, `giro=` (graus), `fantasmas=1`, `levitar=1`, `assustar=1`, `fps=1` (mede o FPS por 4 s). Desiste sozinho se nenhum quadro for desenhado.

Execução: `godot --headless --path . --fixed-fps 60 --script res://tests/verificar_partida.gd`. Se o editor do usuário estiver aberto, copie o projeto, rode `godot --headless --path . --editor --quit` na cópia (reimporta) e teste lá.

Para escrever um teste novo (script `extends SceneTree`):

- Espere um `process_frame` antes de `root.add_child(...)` e não use tipos estáticos de classes do projeto (`Fase`, `Npc`, `Fantasma`: nada de `is Fantasma` ou `Fantasma.CONST`; use grupo ou `load("res://scripts/fantasmas/fantasma.gd")`). Isso força a compilação de `fase.gd` antes de o autoload `GameManager` existir, e a compilação falha. Acesse o autoload com `root.get_node("GameManager")`.
- Um `class_name` novo só entra no cache depois que o editor faz o scan.
- A fase zera `GameManager.sustos` e `mortes` no `_ready` (`comecar_partida`): ponha os sustos depois do `add_child(fase)`. O tutorial roda no `_ready`; chame `fase.tutorial.terminar()` pra pular.
- O mouse não se move com eventos e fica parado no canto. Pra pôr um ponto `p` do chão embaixo dele: `cam.alvo += p - cam.mouse_no_chao(); cam.atualizar()` (e aumente `cam.limite` se o ponto estiver fora). Eventos de mouse vão com `root.push_input(ev, true)`; o hover do GUI só vale no quadro do evento (chame `area._process(0.0)` logo depois).
- O `--headless` não renderiza (nem compila shader). Pra ver a UI ou a cena, use `print_casa.gd`, que espera `RenderingServer.frame_post_draw` e salva `root.get_texture().get_image()`. A janela recebe o mouse de verdade, então desligue o `_input` de quem segue o mouse antes do print.
- Testes que mexem na config devem rodar numa cópia com outro `config/name` no `project.godot`, senão escrevem no `user://` do jogo de verdade.

## Estrutura

```
scene/
  fases/casa/   casa.tscn (a fase) e casa_level.tscn (só o mapa)
  ui/           hud, card_fantasma, lore, pausa, tutorial, vitoria
  menus/        menu, config, credito
  npcs/         npc, policial
  fantasmas/    um por fantasma, mais a comida
  objetos/      prop_debug_levitavel, objeto_quebravel
  efeitos/      estilhacos, fumaca, invocacao
scripts/        mesma divisão: fases, ui, menus, npcs, fantasmas, objetos, efeitos, globais
assets/         sprites, sons, fontes, tema.tres e os shaders
tests/
```

`project.godot` e as cenas referenciam scripts e cenas por UID (`uid://...`). Cada `.gd` tem um `.gd.uid` ao lado: ao mover ou renomear um script, mova o `.uid` junto (ou faça pelo editor), senão as referências quebram. `.godot/` é cache do editor (está no `.gitignore`): não edite.

Fluxo: `scene/menus/menu.tscn` (cena principal) → `btn_play` chama `change_scene_to_file("res://scene/fases/casa/casa.tscn")`; `btn_config` mostra a instância de `scene/menus/config.tscn`; `btn_sair` fecha o jogo. O botão Créditos abre `scene/menus/credito.tscn` (`scripts/menus/credito.gd`), que tem o botão `voltar`, centralizado embaixo, de volta ao menu.

### Fases

Cada fase tem duas cenas em `scene/fases/<nome>/`:

- `<nome>_level.tscn`: só o mapa, pra editar o level no editor.
- `<nome>.tscn`: a fase. A raiz usa `scripts/fases/fase.gd` (`class_name Fase`) e junta o level (instância `level`) com `mundo` (`Node3D` onde nasce o que aparece no jogo: fantasmas, comida, pentagramas, efeitos, policial), `camera`, `UI_main` (instância de `scene/ui/hud.tscn`, a mesma em qualquer fase), `pos` (pós-processamento), `pausa`, `tutorial`, `vitoria` e `lore`. Os exports `ambiente`, `ponto_fuga`, `malha_casa` e `no_comodos` apontam pra nós do level (são export porque os filhos usam antes do `_ready` da fase).

Hoje só existe a `casa`. `GameManager.fase` é a fase atual; ela se registra no `_enter_tree`. Camadas de tela: `pos` 1, `UI_main` 2, tutorial 3, lore 4, pausa 10, fim 11.

### Level da casa (`casa_level.tscn`)

Montado no editor com peças separadas. Não há gerador por script: mudou o level, edite as peças e aperte **Bake NavigationMesh** nas duas regiões de `navegacao`.

- `ambiente`: `WorldEnvironment` (a névoa volumétrica está desligada: era forte demais), lua (`DirectionalLight3D`), a névoa em camadas `neblina_quintal` e `fumaca_pista` (escondida; ligue a visibilidade pra usar) e as partículas `fogos_fatuos` (escondida) e `folhas`.
- `casa` (grupo `nav_casa`): `chao` (peças `CSGBox3D` de piso), `paredes` (peças `CSGBox3D`), `tapete` (`Sprite3D` deitado), `fogo_lareira` (`GPUParticles3D`) e `varal` (lâmpadas, `scripts/fases/varal.gd`: acendem de três em três).
- `terreno` (grupo `nav_fora`): a grama (`CSGBox3D`) e o `NavigationObstacle3D` `sem_casa1`, que tira a casa da malha de fora. `longe` é um plano de 800 m logo abaixo, com o mesmo material da grama (a imagem se repete espelhada até o horizonte): não dá pra ver o vazio em nenhum zoom.
- `navegacao`: `casa` (`NavigationRegion3D`, camada 1), `fora` (camada 2) e os `NavigationLink3D` `porta_esquerda`/`porta_direita` (camada 2), que ligam a grama aos lados do corredor da porta da frente.
- `comodos`: um `Area3D` com `CollisionShape3D` de caixa por cômodo: `quarto`, `sala`, `escritorio`, `quarto2`, `cozinha`. O nome do nó é o nome do cômodo (os requisitos de spawn dependem disso).
- `pontos_festa` (`Marker3D` com `scripts/fases/ponto_festa.gd`), `pontos_armadura` (`armadura1`…`armadura5`, grupo `armadura`) e `pontos_lareira` (`lareira1`, grupo `lareira`), os dois últimos com `scripts/fases/ponto_spawn.gd`.
- `PontoFuga` (`Marker3D`, a saída dos NPCs, no corredor abaixo da casa), `luzes` (`OmniLight3D` com `scripts/fases/luz.gd`), `props` (`prop_levitavel1..3`, `prop_quebravel1..3`) e `convidados` (os 9 NPCs).

## Arquitetura

### Fase (`GameManager.fase`)

`Fase` tem as regras da partida e uma API pra falar entre 3D e tela:

- Tela e mouse: `na_tela(p)`, `atras_da_camera(p)`, `pixels_por_metro(p)` (≈ 88 no zoom 1), `posicionar(item, p)` (põe um `CanvasItem` da UI em cima de um ponto 3D e esconde se estiver atrás da câmera), `mouse_no_chao()` (`Vector3` no chão, é o que substituiu o antigo mouse global), `mouse_em_sprite(sprite, folga)`, `mouse_em_malha(malha)`, `cantos_na_tela(sprite, folga)`, `centro_na_tela(sprite)` e `topo(sprite)` (ponto do mundo no topo do desenho).
- Mapa: `ponto_na_casa(p)`, `comodo_em(p)` (nome do `Area3D`, ou `""`), `comodo_proibido(p, proibidos)`, `ponto_no_comodo(comodo)`, `eh_parede(p)`, `fora_de_casa(p)`, `intensidade_susto(p)` (1, ou `intensidade_musica` se o palhaço está tocando naquele cômodo) e `piscar_luzes(p, duracao)`.
- Regras: objetivos, polícia, amanhecer, sobreposição, `registrar_susto`, `registrar_morte`, `marcado_fugiu` (ver Sistemas).

`eh_parede` e `fora_de_casa` são raios de cima pra baixo (`bate_em`: de y = 5 a y = -0,5) contra as camadas de física 1 (paredes) e 2 (chão da casa). Não use consulta de ponto: o CSG é malha côncava e ela não acha. Fora de casa é "sem chão da casa e sem parede embaixo". Camadas: **1 paredes, 2 chão da casa, 3 terreno (grama), 4 personagens** (NPC em `collision_layer = 8`).

A luz do ambiente (`WorldEnvironment`) vai de `cor_festa` (roxo-azulado) a `cor_vazia` (escuro avermelhado) conforme os NPCs vão embora, em `Fase._process`: a festa morrendo deixa a casa mais sinistra.

### Convenções 3D

- Todo corpo (npc, fantasma, prop) tem a raiz no chão (y = 0); a origem é o pé. Quem voa ou flutua sobe só o sprite (posição local do filho), nunca a raiz. Assim distância entre corpos é `global_position.distance_to(...)`, sem se preocupar com altura.
- O antigo eixo y do 2D é o eixo z do 3D. Direção no chão é `Vector3(x, 0, z)`; ângulo vira `Vector3(cos(a), 0, sin(a))`. Tempos, medo, custos e recargas não mudaram na conversão.
- Navegação: `NavigationServer3D.map_get_path(get_world_3d().navigation_map, de, ate, true, camadas)`. Camada 1 é a casa, 2 é a grama; os NPCs só usam a 1, o zumbi usa 1+2 (máscara 3). Os `NavigationRegion3D` do level são bakeados no editor.
- Entra tudo que nasce no jogo em `fase.mundo`. Ordem de desenho e Y-sort não existem mais: a profundidade 3D resolve.
- Grupos: `npc` (quem está na festa), `convidado` (o npc fica nele até ser liberado: a fase só termina quando esvazia), `fantasma`, `levitavel`, `quebravel` (global, em `[global_group]` do `project.godot`), `luz`, `musica`, `policial`.

### Câmera (`scripts/fases/camera.gd`, `Camera3D`)

Perspectiva (fov 30), de cima, com `inclinacao` fixa de 40° e o ponto do chão que ela olha em `alvo` (começa em `posicao_inicial`). `atualizar()` põe a câmera no lugar a partir de `alvo`, `giro`, inclinação e zoom: o zoom é distância (`distancia_base / zoom`, base 23 m). Scroll muda `zoom_alvo` entre `zoom_min` (0,62) e `zoom_max` (1,6) e o `_process` leva o zoom até lá com suavidade; começa em `zoom_inicial` (0,8). Botão direito arrasta o mapa (o chão acompanha o mouse). Com `pode_girar` (export, ligado), o botão do meio gira em volta do alvo (`graus_por_pixel`). `limite` (`Rect2` em x/z, em metros) segura o alvo, via `limitar(p)`.

- `chao_em(tela)` e `mouse_no_chao()` fazem o raio da câmera contra o plano y = 0.
- `tremer(forca)`: chacoalha pelo `h_offset`/`v_offset` (some em `queda_tremida` por segundo). `chutar(forca)`: tranco pelo fov (0,03 = 3%). Os dois são em tempo real.
- Desfoque em cima e embaixo da tela (`desfoque`, `CameraAttributesPractical`; 0 desliga).
- `mostrar_exterior()` afasta tudo (ao pegar a carta do zumbi e quando ele aparece). `lembrar_de(ponto)` dá um afastamento leve se o ponto está fora da vista (`ponto_na_vista`, que desconta as cartas embaixo), o zoom não passa de `zoom_de_perto` e o jogador não mexeu há `calma_lembrete` s; o zumbi lá fora chama a cada `intervalo_lembrete` (30 s). `aproximar_de(p)` leva a vista até um ponto com zoom até `zoom_aproximar` (1,1; usado pela lista de fantasmas). `conduzindo` é essa ida automática; scroll ou arrasto cancelam (`jogador_mexeu()`).
- **Foco** (lore do NPC): `focar(alvo, lado)` guarda `alvo_antes` (só se não estava em foco nem voltando, então trocar de alvo não perde o enquadramento) e a câmera desliza em tempo real até o alvo, com zoom `zoom_foco` (2,4, maior que `zoom_max`). `lado` 1 deixa o alvo no meio da metade esquerda da tela (painel na direita), -1 na direita. O limite pode empurrar o alvo pra fora do meio; a lore vê isso e põe o painel do outro lado. O zoom do foco não mexe em `zoom_alvo`. Em foco, scroll e arrasto são ignorados. `soltar_foco()` volta ao enquadramento anterior; scroll ou arrasto durante a volta cancelam. Se o alvo some (`queue_free`), a câmera solta sozinha.
- Pra mudar o limite ou o enquadramento, mexa nos exports da `camera` na cena da fase.

### Mundo 3D e materiais

- `assets/chao_pintado.gdshader`: a imagem do chão/grama presa no mundo por `retangulo`; qualquer peça em cima mostra o pedaço certo. Fora do retângulo a imagem se repete espelhada (por isso a grama e o `longe` não têm emenda). Com `recortar` (chão da casa) some onde a imagem é transparente e fora do retângulo.
- `assets/parede.gdshader`: topo escuro, face pra dentro marrom e pra fora bege, decidido pela imagem do chão na frente da face.
- `assets/personagem.gdshader`: sprite em pé virado pra câmera, com contorno, brilho e giro (ver Sprites).
- `assets/alma.gdshader`: silhueta branca 3D (alma do infarto); a textura vai em `texture_albedo` na mão.
- `assets/nevoa.gdshader`: névoa rasteira em camadas. Cada camada é um `MeshInstance3D` com `PlaneMesh` deitado, com fiapos de ruído andando com o vento; várias empilhadas em alturas diferentes (filhas de `neblina_quintal` e `fumaca_pista`) dão volume quando a câmera mexe. Cada camada tem os parâmetros de instância `camada` (muda o ruído) e `forca` (as de cima são mais ralas). Recebe as luzes (a fumaça da pista fica colorida com a festa), some suave onde encosta em parede, chão ou gente (pela profundidade da cena) e, com `usar_mascara`, não entra na casa (usa a imagem do chão). Pra mudar a névoa, mexa no material (`densidade`, `corte`, `escala`, `vento`) ou acrescente/tire camadas. `assets/neblina.gdshader` é a neblina de tela do menu e dos créditos.
- `assets/pos.gdshader` + `scripts/fases/pos.gd` (`ColorRect` `tela` no `CanvasLayer` `pos`): cor (escuros puxando pro roxo, claros quentes), vinheta, granulado e aberração cromática. `fase.pos.chutar(forca)` dá um tranco na aberração, em tempo real; o NPC chama ao subir de nível e o infarto também. `assets/foco.gdshader` escurece a tela em volta do infartado.
- **Luzes**: `OmniLight3D` dentro de `luzes`, todas com `scripts/fases/luz.gd`. O script cuida do `tremor` (vela/lareira), da `falha` (lâmpada apagando sozinha) e, com `cores` + `bpm` + `raio_orbita`, das luzes da pista, que trocam de cor na batida e andam em órbita. Toda `luz.gd` entra no grupo `luz` e tem `piscar(duracao)`. `Fase.piscar_luzes(p, duracao)` pisca as do mesmo cômodo ou a até 3,5 m. Quem chama: o NPC ao subir de nível (mais forte quando foge), o infarto durante o ataque inteiro, e `Fantasma.executar` em toda ação que deu certo. A lua é uma luz enorme e fraca.
- Cada `Fantasma` cria no `_enter_tree` uma luz verde-água fraca, pulsando, perto do desenho. Ela não está no grupo `luz`.
- Decoração: `scripts/fases/varal.gd`. Nada de decoração tem colisão nem conta como parede.

### Sprites de personagem

O desenho de npc e de todo fantasma é um filho `AnimatedSprite3D` chamado **`sprite`** com `scripts/globais/sprite_personagem.gd` (`class_name SpritePersonagem`).

- O shader (`personagem.gdshader`) deixa o quad em pé virado pra câmera, com luz e sombra. **Não** ligue `billboard` no nó nem ponha `material_override` na cena. O Godot não passa a textura do quadro pra material próprio, então o script faz isso a cada troca de quadro/animação.
- `sprite.contorno` (borda branca do hover/seleção), `sprite.brilho` (0 a 1, branco; dá pra tweenar a propriedade `brilho`) e `sprite.giro` (radianos, em volta do pé, no plano do desenho; a `rotation` do nó não aparece). Esticar e amassar com `scale` funciona. `flip_h` e `modulate` continuam valendo.
- `pixel_size = escala_2d_antiga * 1.2 / 88` (escala 2 → 0,0273; 1,5 → 0,0205). O `offset` é em pixels da textura com y **pra cima**: o antigo `Vector2(0, -32)` vira `Vector2(0, 32)`. O pé do desenho fica em y = 0.
- Sprites soltos sem o script (lágrimas, dentes, nuvens do bafo, notas, comida): `AnimatedSprite3D`/`Sprite3D` normal com `billboard = BILLBOARD_FIXED_Y`, `alpha_cut = ALPHA_CUT_DISCARD`, filtro `NEAREST` e `shaded = true`.
- O hover e o clique usam o retângulo do quadro atual projetado na tela (`fase.mouse_em_sprite(sprite, folga)`), então já contam escala, respiração e flip.

### UI presa no mundo

Medidor de medo e monitor do infarto, "!", caveira do marcado, onomatopeias, "+1", letreiros, seta do tutorial e contagem do ímã continuam desenho 2D (`CanvasItem`). Um filho 2D de um nó 3D é desenhado na tela inteira (a posição dele é de tela): por isso cada um é posicionado todo quadro com `fase.posicionar(item, ponto3d)` e escalado com `fase.pixels_por_metro(ponto3d) / 88.0`. Quem recebe posição da HUD passa posição de tela (`fase.na_tela(p)`): `ui.voar_susto(pos_tela, quantos)`, `ui.letreiro(texto, pos_tela)`, `ui.focar(alvo, forca)`, `ui.desfocar()`.

Todo o resto do mundo é 3D: sombra e anel do NPC (malhas achatadas no chão, `disco_no_chao`), alma (`Sprite3D`), pentagrama (`AnimatedSprite3D` deitado, brilhando por `modulate` acima de 1), comida (`Sprite3D`), áreas no chão e quadradinhos de soltar carta (`areas_chao.gd`, `ImmediateMesh` a y ≈ 0,02, unshaded, sem sombra), correntes do ímã e efeito em grupo (`ImmediateMesh`), fumaça/poeira e estilhaços (`GPUParticles3D` de uma vez só, `efeito_unico.gd`, se liberam no `finished`).

### Cursor, áreas e hover

- **Áreas no chão** (`scripts/ui/areas_chao.gd`, criado pela fase em `mundo`): de leve, o alcance das ações do fantasma com o mouse em cima ou no menu de ações (`Fantasma.area_de(acao)` devolve `{"centro", "raio"}` em metros, `{"comodo": nome}` ou `{}`). Arrastando uma carta, quadradinhos brancos (`CELULA` 0,4 m) onde ela pode cair, pela mesma regra de soltar (`area_jogo.pode_soltar_em`). Enquanto escolhe o lugar do ímã desenha a prévia da corrente (`MARCA.desenhar_corrente`).
- **Tema e fonte**: `assets/tema.tres` é o tema do projeto (`gui/theme/custom`): fonte padrão `fonts/Halloween Spooky Acentos.otf`, tamanho 20 e dica (tooltip) 24. A fonte original (`fonts/Halloween Spooky.otf`) não tem letra acentuada; a "Acentos" é uma cópia em que `fonts/fonte_acentos.py` (fontTools) montou as 48 letras acentuadas do português. Se trocar a fonte, rode o script de novo. Abaixo de ~19 px essa fonte fica difícil de ler. Na primeira abertura depois de uma fonte nova, o Godot avisa que não carregou o tema; da segunda vez passa.
- O tema estiliza os controles no preto e branco do jogo (a interface não tem outra cor; o único tom quente é o papel das cartas, `Color(0.86, 0.84, 0.76)`): `Button` com fundo `Color(0.05, 0.04, 0.06, 0.92)`, sem borda (a largura foi zerada de propósito; só sobrou o `border_color`), cantos retos e margem 18×8; hover com fundo, borda e texto mais claros; pressed invertido (fundo de papel, texto escuro); disabled apagado; foco `StyleBoxEmpty`. `PanelContainer` e `TooltipPanel` têm o mesmo fundo e **não têm borda** (o painel leva `content_margin` de 2 px no lugar). `BotaoSemBorda` é uma variação de `Button` que só o botão dos objetivos usa (`theme_type_variation`). Num `StyleBoxFlat` à mão o `border_color` sozinho não desenha nada: a largura (`border_width_*`) é 0 por padrão. `HSlider`, `CheckButton` e `HSeparator` também estão no tema. `PainelOpaco` é uma variação de `PanelContainer` sem transparência, usada no painel da config. Não ponha `theme_override_styles` nos botões das cenas; só a carta do baralho fica de fora (`Button` flat com seis `StyleBoxEmpty`). Texto de botão sem estilo próprio é papel.
- Nenhum texto do jogo tem borda preta (pedido do jogo): não use `outline_size`.

## Sistemas do jogo

### Config, pausa e GameManager

- **Config** (`scene/menus/config.tscn`, `scripts/menus/config.gd`, `class_name Config`): volume do bus Master e tela cheia, salvos em `user://config.cfg` a cada mudança. `Config.carregar()` (no `_ready` do `GameManager`) reaplica ao abrir o jogo. A mesma cena é usada no menu e na pausa; o Voltar esconde a config e emite `voltar`.
- **Pausa** (`scene/ui/pausa.tscn`, instanciada na fase): `CanvasLayer` na layer 10 com `process_mode = ALWAYS`. Esc (`ui_cancel`) alterna `get_tree().paused` (com a lore de um NPC aberta, o Esc fecha só ela: o `_input` da lore consome a tecla antes do `_unhandled_input` da pausa). Botões: Continuar, Como jogar (reabre o tutorial), Configurações, Menu principal (volta o tempo ao normal, `GameManager.tempo_normal()`) e Sair do jogo.
- **`GameManager`** (autoload, `scripts/globais/gameManager.gd`): guarda `fase`, `sustos` (a moeda: quantas vezes algum NPC subiu de nível de medo) e `mortes` (infartos); `comecar_partida()` (no `_ready` da fase) volta para `SUSTOS_INICIAIS` (5) e 0 mortes. Também é dono da câmera lenta: `mudar_tempo(alvo, duracao)` desliza o `Engine.time_scale` com um tween só (em tempo real, `TWEEN_PAUSE_PROCESS`, então termina mesmo pausado; quem pede por último vale, assim o menu de ações, o arraste de carta e a lore nunca brigam) e `tempo_normal()` volta a 1 na hora (troca de cena, Menu principal, fim da partida). Em `GameManager.som` fica o `Som`.

### HUD e contadores

- **Contadores** (`UI_main/contadores`, canto de cima à esquerda): `sustos` (ícone `assets/UI/icon_susto.png` + número grande) e embaixo `mortes` (`icon_morte.png`, menor). O número das mortes vai de branco a vermelho conforme chega em `limite_mortes`. A explicação é o `tooltip_text` de cada `HBoxContainer` (a das mortes é montada no `_ready` do `ui_main`); número e ícone ignoram o mouse, então passar em qualquer um mostra a dica. Os contadores precisam vir depois da `area_jogo` na árvore, senão ela fica por cima e come o mouse. Os contadores crescem do meio quando ganham e encolhem quando gastam. O "+1" voa até o ícone de sustos (`ui_main.voar_susto`; o contador só soma quando ele chega, via `voando`).
- **Relógio** (`ui_main.relogio`, embaixo dos contadores, vermelho no último minuto). `Fase.tempo_limite` é 1080 s; se só sobrar o policial (que não foge), faltam no máximo `tempo_so_policial` (90 s). O relógio espera o tutorial (`tutorial.rodando()`). Acabando o tempo, `Fase.amanhecer()` manda todo mundo fugir e a partida termina como sempre, com o rank.
- **Lista de fantasmas** (`scripts/ui/lista_fantasmas.gd`, criada pelo `ui_main`, embaixo do ímã): um ícone por fantasma na casa, desenhado no `_draw` (ícone e nome vêm da carta). Mouse em cima liga `Fantasma.destacado` (o mesmo contorno do hover) e clique chama `camera.aproximar_de`.

### Objetivos

Painel `UI_main/objetivos`, no canto de cima à direita (ancorado nele, 380 de largura), atualizado todo frame por `ui_main.atualizar_objetivos()`. Para vencer é preciso esvaziar a casa e cumprir um destes:

1. Matar os `quantos_marcados` (2) marcados: `Fase.marcar_alvos()` sorteia no começo; `candidatos_a_marcado()` só aceita NPCs que uma carta já liberada mata do coração (compara `infarto_tipo`/`infarto_tier` com `tipo`/`tier` dos cards), fora o policial. O marcado ganha uma caveira vermelha balançando em cima da cabeça (`Npc.marcar()`) e um retrato no painel, vermelho se ele morre e apagado se foge vivo. Marcado que foge passa a marca pra outro convidado; o objetivo só falha se não sobrar gente pra completar.
2. Assustar todos os cômodos (`comodos`) dentro de `janela_comodos` (6 s): todo susto que pega passa em `Fase.registrar_susto(pos)`.
3. Matar um policial.

Os três ficam em `objetivo_marcados`, `objetivo_comodos` e `objetivo_policial`. Estrutura: `objetivos/margem/coluna` tem o `cabecalho` (título, `resumo` e `botao`) e o `recorte` (`Control` com `clip_contents`), que guarda o `corpo` com o separador e as linhas (`casa`, `marcados`, `retratos`, `comodos`, `policial`); `ui_main.objetivos` aponta pro `corpo`.

Comportamento: o painel começa aberto e se fecha sozinho depois de `tempo_objetivos` (12 s, em tempo real). Toda vez que abre de novo (botão ou `abrir_objetivos(true)`, como faz o tutorial) fecha depois de `tempo_reaberto` (8 s). Com o mouse em cima ele não fecha (`get_viewport().get_mouse_position()` dentro do retângulo do painel, que ignora o mouse; sai uns 1,5 s depois que o mouse sair). Quando uma linha muda de estado (feito ou falhou, detectado em `linha()` por `estado_linhas`), `avisar_objetivos()` abre o painel por `tempo_aviso` (6 s). Abrir e fechar é animado em `abertura_objetivos` (0 a 1, tween de 0,2 s com `set_ignore_time_scale()`): `mostrar_objetivos(t)` encolhe o `recorte` (altura = altura natural do corpo × t), sobe e some com o corpo, mostra o `resumo` na barra e gira a setinha do botão; roda todo frame pra acompanhar o texto e chama `reset_size()` porque o painel só cresce sozinho. O corpo é ancorado no topo do `recorte`: para deslizar use `offset_top`, não `position`. Fechado sobra uma barra de 380×54 com título, resumo (só "1 feito" / "2 feitos" quando há objetivo cumprido) e botão. As linhas ficam em tom de papel, brancas quando feitas e apagadas quando falham (a cor só muda na mudança de estado). O botão dos objetivos não tem texto: a setinha é desenhada no sinal `draw` dele. Em teste headless o `get_mouse_position()` fica em (0, 0): para simular o mouse em cima, leve o painel até lá (`painel.global_position = Vector2(-60, -10)`).

### Polícia

No infarto número `limite_mortes` (export da fase, padrão 3), `Fase.chamar_policia()` instancia `cena_policial` (`scene/npcs/policial.tscn`, que herda o `npc.tscn` com `policial = true`, `resistencia = 2` e visual próprio) no `PontoFuga`, com letreiro "POLÍCIA!", sirene (uma `OmniLight3D` piscando vermelho e azul, mais o som por 6 s) e "UIU UIU". Ele vai até onde foi a última morte (`ultima_morte`) e depois vira um NPC da festa. Ele não foge: só sai infartado (a barra para em 99 no nível 4) ou, se amanhecer, vai embora. `resistencia` divide os pontos de todo susto; o policial é azulado (`cor_sprite`) e somente o Cavaleiro mata ele do coração (`Espectro`, tier 1). Entra na conta de `npcs_no_comeco`. Tem visual `assets/npc/policial.tres` próprio, fora da composição inicial.

### Sobreposição e fim da partida

- **Sobreposição** (`Fase.vigiar_sobreposicao`, a cada 0,5 s): dois corpos (npc ou fantasma) a menos de `distancia_sobreposicao` (0,45 m) por `tempo_sobreposicao` (20 s): um deles chama `redirecionar()` (npc troca de atividade, quem passeia sorteia outro destino, o morcego pega a direção mais aberta; quem nasce em ponto fixo não muda). NPC nunca fica parado num ponto mais que `tempo_max_parado` (12 s).
- **Fim**: quando o grupo `convidado` esvazia (todo mundo fugiu ou infartou e os corpos sumiram), `Fase.terminar()` espera 0,8 s e chama `vitoria.mostrar(...)` (`scene/ui/vitoria.tscn`, layer 11, `process_mode = ALWAYS`): "Vitória!" se algum objetivo foi cumprido, "Fim de festa" se não. A tela pausa o jogo, segura o Esc e tem Jogar/Tentar de novo (`reload_current_scene`) e Menu principal.
- **Rank** (`scripts/ui/vitoria.gd`, `calcular_rank`): S só com todo mundo infartado (`fugiram == 0`, o policial conta se veio); A com 2 objetivos, ou 1 objetivo e pelo menos metade dos convidados mortos; B com 1 objetivo; C sem objetivo. A tela mostra os números um a um e a letra cai como carimbo (`carimbar()`: som, clarão, anéis, tremida; A e S têm raios e almas subindo). Clicar pula a animação. O selo é desenhado no `draw` de `selo`.

### Tutorial

`scene/ui/tutorial.tscn`, `scripts/ui/tutorial.gd`, layer 3. Roda sempre que a partida começa e é curto: 13 passos de uma frase (até ~1,5 linha, no máximo uns 90 caracteres) num painel de papel, sem borda (1000 de largura, "Tutorial n/13"), com o texto à esquerda e "Próximo" / "Pular tutorial" à direita, e o jogo rodando atrás. O primeiro passo fica no meio da tela com o resto escurecido (`fundo`); os outros, no topo, entrando com um tranco e som, e um tranquinho a cada 4 s no mesmo passo. A pausa tem "Como jogar".

Os passos ficam na lista `passos` de `comecar()`, em ordem de jogar: gancho, vaso, moeda, carta, ação, bônus em grupo, ficha do convidado, como matar, objetivos, ímã, câmera, polícia e o fim.

- Um passo com `feito` (`Callable`) passa sozinho ("Boa!" por 0,8 s); `auto` passa depois de N s; `destaque` faz um controle da tela pulsar (`modulate`); `abrir_objetivos` reabre o painel de objetivos.
- `alvo` (`Callable` que devolve algo do mundo) faz o alvo pulsar de brilho e desenha em cima dele uma seta amarela grande quicando (nó `seta`, pelo `draw` do próprio tutorial, posicionada todo quadro com `fase.posicionar` no topo do alvo; é polígono, sem asset). Alvo de npc/fantasma pulsa com `sprite.brilho`; o vaso é o export `objeto_levitavel` do tutorial (na fase da casa, `level/props/prop_levitavel1`), que expõe `topo()` e `destaque` (0 a 1). Enquanto o vaso sai do grupo `levitavel`, a seta fica oculta. No passo do vaso a seta vai pro vaso do cômodo com gente (`levitavel_com_gente`) e o texto muda enquanto ele segura (`fazendo`/`texto_fazendo`); ao segurar, `trancar_quem_assusta()` prende alguém do cômodo (ou traz o mais perto) com `Npc.atrair` até ele subir de nível.
- O passo da ficha do convidado tem `alvo` no marcado e `feito` ao abrir e fechar a lore; o painel some enquanto a ficha está aberta.
- O tempo é em tempo real (`delta / time_scale`).
- Ao acabar o tutorial do começo da partida (`do_comeco`, inclusive pulando), todos voltam ao medo zero (`Npc.zerar_medo`, os sustos ganhos ficam) e aparece "VALENDO!"; o "Como jogar" da pausa não zera.

### Medo e sustos (NPC)

`Npc.tomar_susto(tipo, pontos, fantasma)`: os pontos são reduzidos por `1 / (1 + nivel_medo * reducao_por_nivel)`, divididos por `resistencia` e multiplicados por `fase.intensidade_susto(pos)`. Quando `barra_susto` chega a 100, zera, `nivel_medo += 1` e `GameManager.sustos += 1` (com um "+1" subindo em cima do NPC e uma tremida de tela). Níveis 1–2 → `Normal`, 3–4 → `Assustado`, ≥5 → `fugir()`: anda até `fase.ponto_fuga` e faz `queue_free()` ao chegar a `distancia_fuga` (0,17 m). A partir do nível `NIVEL_INFARTO` (3), um susto do fantasma que mata aquele NPC do coração faz ele infartar na hora. O mesmo tipo de susto seguido conta normal.

- **Game feel**: a cada susto o NPC estica no pulo e amassa na queda (`deformacao`, que multiplica a escala do sprite junto com a respiração), pisca claro (`sprite.brilho`), mostra um "!" e o medidor pulsa. O medidor (desenhado no sinal `draw` do filho `medidor`) é a barra (enche suave, `barra_mostrada`) de 60×8 px com borda de 2 px e os 5 níveis em quadradinhos de 9×7 em cima, a `ALTURA_MEDIDOR` (0,18 m) acima do topo do desenho; a caveira do marcado fica `altura_marca` acima do medidor. Aparece quando há medo. Ao subir de nível: "!!", `GameManager.hitstop()` (congela o jogo com `time_scale` 0.05 por um instante; não mexe se o menu de ações ou o arraste de uma carta estiver em câmera lenta), `camera.tremer()` e `camera.chutar()`, mais fortes quando ele foge. Quem foge corre com o dobro de velocidade e as pernas no dobro, e na saída sai do grupo `npc` e some com fade (`sair_da_festa`).
- **Grito**: quando o NPC sobe de nível sem fugir, `Som.gritar()` sorteia um dos `susto1..6`.
- **Fugir do cômodo**: só quando o medo sobe de nível (`Npc.fugir_do_comodo()`): quem está num cômodo corre `tempo_fuga_comodo` (3 s, velocidade dobrada) para um ponto de outro lugar. O Cavaleiro também manda quem levou a espadada sair de perto (`tempo_fuga`), e a mordida da Caveira, pra outro cômodo.
- **Efeitos no NPC**: `velocity +=` para empurrão; `direcao_correr` (`Vector3`) faz o NPC correr reto até `eh_parede` e então chama `atordoar(duracao_stun)`; `atordoar(tempo, dreno)` congela o NPC e faz a `barra_susto` cair `dreno` por segundo durante o stun; `correr_para_outro_comodo(tempo)` escolhe outro cômodo e anda com o dobro da velocidade. Stun e corrida têm prioridade sobre fuga e passeio em `_physics_process`.

### Festa e movimento do NPC

`Npc` (`scripts/npcs/npc.gd`, `scene/npcs/npc.tscn`, `CharacterBody3D`, grupos `npc` e `convidado`) tem um `NavigationAgent3D` e espera o mapa de navegação sincronizar (`navigation_ready`) antes de andar. Cada instância precisa do export `visual` (um `SpriteFrames` em `assets/npc/`); a fase ele pega em `GameManager.fase`.

Simula uma festa: cada um começa parado onde foi colocado por 0–20 s (assim não saem todos juntos), tem velocidade própria (±15%, base `speed` 1,7 m/s) e um gosto (`preferencia`: dançar, beber, conversar, descansar ou aleatória; na casa o atleta prefere dançar). `escolher_atividade()` sorteia um **ponto da festa** com vaga (`ponto_festa.gd`, `Marker3D` no grupo `ponto_festa`: `atividade` (dançar, beber, conversar, descansar, banheiro), `vagas`, `raio`, `tempo_min/max`), com peso 5 no gosto dele, nunca o ponto de onde acabou de sair e menor quanto mais longe; vai até um lugar livre em volta (`ponto_festa.lugar_livre()` escolhe o mais longe dos outros) e fica lá. Com `chance_zanzar` só dá uma volta até um ponto aleatório de algum cômodo. Parado no ponto, `olhar_pro_ponto()` vira pro meio do ponto (rodinha de conversa). Assustado prefere conversar a dançar. `correr_para_outro_comodo()` e `fugir()` liberam a vaga (`sair_do_ponto()`). Pra mexer na festa, mova ou crie pontos no level; cada ponto novo só precisa do script.

- **Visual**: os sprites vêm de `assets/REFACTOR NPCs/`: cada sheet tem 192×64, com 6 quadros de 32×64 na animação `andar` (8 FPS), desenhada virada pra direita. A casa começa com exatamente 9 convidados, um de cada: Gótica (`npc`), Atleta (`npc2`), Hippie (`npc3`), Psicopata (`npc4`), Criança (`npc5`), Cientista (`npc6`), Idoso (`npc7`), Advogado (`npc8`) e Adulto religioso (`npc9`). Os recursos antigos `cheerleader.tres` e `gordo.tres` não são usados. Pra um NPC novo, crie um `.tres` igual, com o sheet dele e as metadatas de lore e de infarto.
- **Animação**: andando toca `andar` e faz `flip_h` pelo sinal de `velocity.x`; parado, `stop()` e `respirar()`: o sprite estica pra cima de 0 a `pixels_respiracao` pixels de tela, sempre em pixel inteiro (escala contínua em pixel art fica piscando), mais rápido (`velocidade_ofegante`) quando `Assustado`, com fase aleatória por NPC. O pivô do `AnimatedSprite3D` fica nos pés (origem do NPC; o `offset` vem da altura do quadro e da margem transparente dos pés). Nada no NPC pode mexer no sprite todo frame com valor aleatório: uma tremida de ±1 px no `Assustado` deixava os parados piscando.
- **Parede**: o NPC se move pela malha de navegação; `ficar_na_malha()` segura ele nela a cada quadro por `Fase.ponto_na_casa`. NPCs têm máscara de colisão 0 com outros NPCs: um parado numa porta não trava quem vem atrás.
- **Espaço**: `abrir_espaco()` afasta de quem está a menos de `DISTANCIA_SOCIAL` (0,82 m), parado e de leve andando. `area_jogo.npc_sob_mouse` pega o npc com o meio do desenho mais perto do mouse, então dá pra clicar em qualquer um de um grupo.
- **Destravar**: `verificar_travado()` troca de destino depois de `TEMPO_TRAVADO` (3 s) tentando andar sem sair do lugar; quem está em `Foge` nunca recebe outro destino (`correr_para_outro_comodo` ignora) e sai da festa ao fim do caminho.

### Lore do NPC

`scene/ui/lore.tscn`, `scripts/ui/lore.gd`, `CanvasLayer` na layer 4 (instanciada na fase como `lore`). Clicar num NPC abre a árvore de lore dele, pra ensinar o jogador a infartar cada tipo.

- **Dados**: no `.tres` de cada visual em `assets/npc/` ficam `metadata/nome_tipo` e `metadata/lore`, um Array de 3 Strings (os nove convidados e o policial têm as três frases preenchidas). Os exports `nome_tipo` e `lore` do `Npc` sobrescrevem por instância; o policial não sobrescreve. `Npc.dados_lore()` devolve `{"nome", "lore"}` já resolvidos.
- **Desbloqueio** pelo nível de medo: `Npc.NIVEIS_LORE = [1, 3, 4]` (o 1º texto no nível 1, o 2º no 3, o 3º no 4).
- **Hover**: `area_jogo._process` marca `npc.em_destaque` no NPC que o clique abriria (`npc_sob_mouse()`: grupo `npc`, fora do estado `Infarta`) e põe a mãozinha no cursor. Nenhum anel com fantasma embaixo do mouse, carta sendo arrastada (`gui_is_dragging()`), menu de ações aberto, outro controle em cima do mouse (`gui_get_hovered_control()` diferente da `area_jogo`) nem no NPC que a lore já mostra. O anel é o filho `anel` do NPC (disco achatado de papel nos pés, pulsando de leve), que aparece e some em tempo real (`alfa_anel`). O hover do fantasma é outro (contorno branco, `sprite.contorno`, e cresce 8%).
- **Clique**: o `_gui_input` da `area_jogo` abre a lore se não pegou fantasma (fantasma tem prioridade: ele fecha a lore com `lore.fechar(false)` e abre o menu de ações) e `npc_sob_mouse()` achou alguém; clicar em outro NPC com a lore aberta troca o foco.
- **Ao abrir** (`Lore.abrir(npc)`): `camera.focar(npc, lado)` e `GameManager.mudar_tempo(tempo_lento, 0.15)` (0,25, o mesmo do menu de ações e da carta). O painel (`PanelContainer` do tema, sem borda) fica na metade direita e o NPC no meio da esquerda; se o limite da câmera empurrar o NPC pra metade direita, o painel vai pra esquerda (`lado`, decidido ao abrir). Topo: retrato (1º quadro de `andar`, filtro nearest, uns 120 px de altura), nome do tipo, "Nível de medo N" com 5 quadradinhos e o botão Fechar. Embaixo, a árvore: 3 linhas (`criar_no()` no `_ready`), cada uma com um marcador (linha vertical e bolinha, desenhados no `draw`) e uma caixa de texto. Liberado: o texto da lore. O próximo bloqueado: cadeado (`assets/UI/cadeado.png`) e "Atinja nível de medo X para desbloquear mais informações". Os seguintes: cadeado e "???". Se o NPC sobe de nível com o painel aberto, o `_process` vê `nivel_medo != nivel_mostrado` e `atualizar(true)` acende o nó liberado (pulinho, brilho e anel no marcador).
- **Fechar**: botão, clique fora do painel (no vazio ou num fantasma; num NPC troca o foco), botão direito, ou Esc (o `_input` da lore consome o Esc, então a pausa não abre junto; com o jogo pausado o `_input` não roda e o Esc só despausa). Fecha sozinha se o NPC sair da festa, infartar ou for liberado, e quando uma carta da loja é pega (`fechar(false)`: o baralho cuida do tempo). `fechar()` solta o foco da câmera e volta o tempo (`mudar_tempo(1.0, 0.1)`). A lore só lê `GameManager.fase` em `abrir()`, não no `_ready`.

### Infarto (`Estado.Infarta`)

Cada visual de NPC tem `metadata/infarto_tipo` (nome do `Fantasma.Tipo`: `Aparicao`, `Poltergeist`, `Espectro`, `Demonio`) e `metadata/infarto_tier` no `.tres`; `Npc.mata_do_coracao(fantasma)` compara tipo e tier exatos. Vale em qualquer susto a partir do nível `Npc.NIVEL_INFARTO` (3), sem precisar encher a barra (quem já está fugindo não infarta). Relações atuais:

| NPC | Fantasma (tipo, tier) |
|---|---|
| Policial | Cavaleiro (Espectro, 1) |
| Advogado | Caveira (Aparição, 3) |
| Gótica, Cientista | Geleia Roxa (Aparição, 2) |
| Psicopata | Criança Medonha (Poltergeist, 1) |
| Adulto religioso | Diabrete (Demônio, 1) |
| Atleta | Palhaço (Poltergeist, 3) |
| Hippie | Cão Possuído (Espectro, 2) |
| Idoso | Zumbi (Demônio, 2) |
| Criança | Morcego (Aparição, 1) |

Um NPC novo precisa das duas metadatas no `.tres` dele. Não tem arte: `infartar()` faz tudo no código. Sai do grupo `npc` na hora (nenhum fantasma mira nele; zumbi, cão, caveira e geleia desistem de quem saiu do grupo; continua em `convidado` até sumir) e ignora susto, stun e corrida. Sequência (constantes `INFARTO_FIBRILA` 1,6 s, `INFARTO_PARA` 2,1 s): hitstop, tranco e `ui.focar()` (tela escurece em volta dele, shader `assets/foco.gdshader`, animado por `foco_forca`/`foco_raio` no `ui_main`, porque no headless o tween não acha `shader_parameter/...`); o medidor vira um monitor cardíaco (`desenhar_monitor`) com as batidas acelerando, coraçãozinho pulsando junto, o desenho tremendo de pixel em pixel, curvando e ficando pálido; fibrilação; linha reta, o coração parte em duas metades (`metade_coracao`, que se encaixam pela `RACHADURA`) e o letreiro "INFARTO!" (`ui.letreiro`); ele cai duro girando o sprite em volta dos pés (`sprite.giro`), poeira (`fumaca.tscn`), e o "+N" (1 + `bonus_infarto`, padrão 2) sai do corpo; a alma (`Sprite3D` com `alma.gdshader`) sobe e some; a tela clareia e o corpo some com fade.

### Poder de atrair

`scripts/ui/poder_atrair.gd`, o botão do ímã embaixo do relógio, criado pelo `ui_main` (recarga 120 s): clique no botão, no convidado e no lugar (botão direito ou Esc cancelam, em câmera lenta). A `area_jogo` repassa os cliques (`clique_no_mapa`) e `usar(npc, onde)` chama `Npc.atrair(onde, tempo)`. Atraído (`atraido`, `tempo_preso` 30 s, que conta depois de chegar), o NPC corre até lá e nada tira ele: `fugir`, `escolher_atividade`, `direcao_correr` e comida são ignorados, e a barra para em 99 no nível 4, então só o fantasma certo mata. Amanhecer solta.

`scripts/efeitos/marca_atracao.gd` é o feel, por etapas: `Puxando` (corrente saindo do ponto, rastro de cópias do desenho, ele inclinado), `Preso` (impacto "PRESO!" ao chegar, quatro correntes até o corpo, ele se debate de tempos em tempos, tique-taque e círculo piscando nos últimos 5 s) e `Fim` (correntes arrebentam em cacos, "CLAC!"; se ele morreu preso, só somem). `desenhar_corrente(malha, de, ate, cor, tempo, tremor)` é função estática que só acrescenta triângulos (quem chama já abriu `surface_begin(PRIMITIVE_TRIANGLES)`); o `areas_chao` usa pra prévia.

### Baralho (a loja)

`UI_main/painel_fantasmas` é um `Control` na largura toda, colado embaixo (300 de altura, `mouse_filter` IGNORE), e `lista` é um `Control` comum (não Container) com `scripts/ui/baralho.gd`, que posiciona as cartas (os filhos, instâncias de `scene/ui/card_fantasma.tscn`; os nomes `card_morcego`, `card_geleia`… são usados por `Fase.marcar_alvos` e pelos testes). Cada carta é um `Button` flat de 392×540 (a arte `assets/UI/fundo carta.png`, 980×1350, na escala 0.4, com mipmaps ligados no `.import`), com pivô na base-centro e `scale` 0.5.

- Em repouso as cartas ficam em leque centralizado (`passo` 150, `graus_por_carta` 2,5° a partir do meio, as pontas mais baixas, só os ~110 px de cima aparecem; com muitas cartas o passo encolhe até caberem). Com o mouse em cima a carta sobe por inteira (base 10 px acima da borda, escala 0.9, sem giro, `z_index` 5) com tween de 0.12 s; arrastando (`gui_is_dragging()`), todas voltam ao repouso. O hover é do baralho, calculado no `_input` pela geometria das cartas (a levantada vale até o fim da tela, senão a faixa de 10 px embaixo dela pisca) e não por `mouse_entered`; enquanto uma está levantada as outras ficam com `mouse_filter` IGNORE, porque o Godot ordena o clique pela árvore e ignora o `z_index`. O layout recalcula no `resized`.
- Cada carta preenche tudo a partir do fantasma: nome (uma palavra por linha, fonte 64 que diminui até caber), custo (fonte 76), "restam N" (ou "resta 1"), o `icone` (arte, filtro NEAREST), "Habilidades" / "MEDO", uma linha por `Acao` (`resumo` à esquerda, medo à direita via `Acao.texto_medo`; a lista tem 142 px: resumo 22 e medo 52, ou 19 e 40 com 3 ações) e o rodapé de restrição de spawn. Logo abaixo do nome fica a linha `tipo`, discreta (fonte 20, cor `Color(0.36, 0.34, 0.3)`): "Poltergeist · tier 1", com `Fantasma.NOME_TIPO` e o tier. Ela acompanha nome de 1 ou de 2 linhas; com 2 linhas a `arte` desce. Os textos são `Label` escuros (`Color(0.08, 0.08, 0.08)`, definido num `Theme` na raiz da carta), sem borda. Fantasma novo com mais de 3 ações ou resumo longo precisa de fontes menores.
- Arrastar uma carta deixa o jogo em câmera lenta (`tempo_lento`, 0,25): o `_process` do `baralho.gd` vê `gui_is_dragging()` com uma carta dele nas mãos (`atualizar_tempo`, que também roda no `NOTIFICATION_DRAG_END`, então soltar, cancelar ou pausar no meio sempre devolve o tempo; o `_exit_tree` chama `tempo_normal()`). `force_drag` (testes) não manda `NOTIFICATION_DRAG_BEGIN`, por isso o começo é por polling.
- A carta guarda pra silhueta no ponto de spawn: `silhueta` (textura do 1º quadro do sprite), `silhueta_pixel` (`pixel_size` × escala) e `silhueta_offset`.
- `usos` (padrão 5, export por cena do fantasma) é quantas vezes ele pode ser comprado: a carta guarda `restantes` e trava ao zerar. A compra (descontar sustos e `restantes`) fica em `card_fantasma.comprou()`, chamado pela `area_jogo` ao soltar. As ações não têm limite, só recarga.
- `mortes_para_liberar` (padrão 0; caveira e palhaço têm 2): a carta só libera com `GameManager.mortes >= N`. A carta travada fica desabilitada e escura (`trava/escuro`: o fundo da carta em preto por cima de tudo, sem transparência, senão deixa ver as outras do leque), com o cadeado (`assets/UI/cadeado.png`, 32×32, filtro nearest) e o texto "Libera com N mortes"; arrastar chacoalha como sem sustos. Quando libera, `liberou()`: duas piscadas aditivas (`brilho`) e a arte e o custo dão um pulinho. Carta travada não conta pra sortear marcado.
- **Soltar** (`scripts/ui/area_jogo.gd`, `Control` de tela cheia com `mouse_filter = PASS`): cobra o custo e começa a invocação. Regras de spawn (exports do `Fantasma`): `comodo_spawn` (só naquele cômodo; vale como prefixo, então `"quarto"` aceita `quarto` e `quarto2`; a carta mostra no rodapé "Só pode ser spawnado em:" e o cômodo), `comodos_proibidos` (lista de prefixos, via `Fase.comodo_proibido`), `pontos_spawn` (nome de grupo: só encaixa num `Marker3D` livre desse grupo, com `ponto_spawn.gd`, que guarda o `ocupante` e, enquanto um card com essa regra é arrastado, mostra o desenho do fantasma em branco e meio transparente no lugar, com o `alma.gdshader`) e `fora_de_casa` (só onde `Fase.fora_de_casa(pos)`; o rodapé mostra "Só pode ser spawnado:" e "Do lado de fora"). Fora isso, só dá pra soltar onde `Fase.eh_parede(pos)` é falso. Por isso os cômodos usados como requisito precisam ter nome (hoje `cozinha`, `quarto` e `quarto2`).
- **Invocação** (`scene/efeitos/invocacao.tscn`, `scripts/efeitos/invocacao.gd`): soltar uma carta não cria o fantasma na hora. A `area_jogo` cobra, reserva o ponto fixo (se tiver) e põe a invocação em `fase.mundo`. O pentagrama (`assets/pentagrama.png`, 12 quadros a 16 fps, `AnimatedSprite3D` deitado, brilhando por `modulate` acima de 1; as brasas são aditivas) se desenha pulsando cada vez mais rápido, com luz vermelha e brasas; no fim segura aceso, e no clarão o fantasma entra em `fase.mundo` e chama `aparecer()` ("VUUSH!", tremida, tranco no pós, fumaça). No clarão todo NPC a até `raio_susto` (1,82 m) do pentagrama leva `tomar_susto("invocacao", medo_susto, fantasma)` (`medo_susto` 20 — com o bônus em grupo) e sai uma onomatopeia de susto ("BU!" ou "AAAH!") além do "VUUSH!", só se alguém se assustou. Quem testa compra precisa esperar ~1,3 s até o fantasma existir.

### Fantasmas

Toda cena de fantasma tem como raiz um script que estende `Fantasma` (`scripts/fantasmas/fantasma.gd`, `Node3D`, com `custo`, `tier`, `tipo` e `usos`), o filho `sprite` (`SpritePersonagem`) e entra no grupo `fantasma` no `_enter_tree`; é por esse grupo que o clique os encontra. A raiz fica no chão. O clique usa `mouse_em_cima()` (retângulo do sprite projetado, `fase.mouse_em_sprite`), com prioridade sobre o clique num NPC.

- **Ações** (nada é automático): `Fantasma.acoes` é um `Array[Acao]` (`scripts/fantasmas/acao.gd`: `nome`, `descricao`, `recarga`, `metodo`, `resumo`, `propriedade_medo`, `mira`, `em_grupo`), definido como sub-resource na cena de cada fantasma. Apertar e segurar o botão esquerdo num fantasma (`_gui_input` de `area_jogo`; `fantasma_sob_mouse()`) abre `UI_main/menu_acoes` no ponto do clique, com câmera lenta (`mudar_tempo(tempo_lento, 0.15)`; ao fechar volta a 1). O menu desenha tudo no `_draw()`: os ícones (`Acao.icone`) lado a lado acima (ou abaixo, perto do topo da tela), com um anel de recarga, e a "bolinha", que é o arraste do mouse vindo do `_input` e limitado ao alcance. A bolinha dentro de um ícone mostra `painel_descricao` (a descrição e uma linha "Medo X"). Soltar com a bolinha num ícone chama `Fantasma.executar(acao)`, que só chama o `metodo` se a recarga zerou. O método devolve `false` quando não deu pra executar, e aí não gasta a recarga. A recarga desconta no tempo do jogo (`delta`), então desacelera na câmera lenta. Ações que dependem de alguém perto (choro, espada, mastigar, lambidão) são manuais como as outras. O menu abre com `abertura` 0→1 (tween com `set_ignore_time_scale`); o ícone sob a bolinha cresce e solta um anel (`realce`, `piscada`).
- **Hover**: contorno branco (`sprite.contorno`) e o fantasma cresce 8%. Tem histerese: `no_hover` (decidido no `_process`) deixa a folga de `mouse_em_cima()` 25% maior depois de entrar, porque o fantasma cresce e o centro do desenho anda (sem isso o hover piscava na borda). `Fantasma.piscar(vezes, duracao)` usa o `sprite.brilho`.
- **Ação com mira** (`Acao.mira`, hoje a comida da geleia): soltar no menu chama `area_jogo.comecar_mira`, com câmera lenta; clique no mapa chama `Fantasma.executar_mira(acao, onde)` e só aí gasta a recarga. Botão direito ou Esc cancelam. O fantasma diz onde vale em `mira_valida`, e `Fase.mirando` impede o clique de pegar o objeto levitável.
- **Medo nas ações**: cada `Acao` tem `resumo` (texto curto pra carta) e `propriedade_medo` (nome da variável do fantasma com o medo daquela ação, ex.: `medo_lambida`; o palhaço usa `intensidade_musica`, float, que aparece como "x1.5"; vazia = "-"). O `descricao` não leva "Medo N.": o número vem da propriedade, na carta e na linha "Medo X" do menu.
- **Caminho dos fantasmas**: nenhum fantasma atravessa parede. `Fantasma.andar_pelo_caminho(destino, passo)` anda um passo seguindo `NavigationServer3D.map_get_path` na camada 1 (a malha da casa, a mesma dos NPCs): guarda `caminho`, recalcula quando o destino muda mais de ~8 px (0,1 m), quando ficou um quadro sem andar ou quando veio vazio (o mapa ainda não sincronizou), e o último trecho até o destino é reto e curto. Sem caminho, fica parado. Quem usa: caveira (cabeçada e volta pra `casa`), diabrete (ida ao objeto), geleia (lambidão) e cão. O zumbi usa o próprio `NavigationAgent3D` (camadas 1+2) e o morcego quica com `parede_adiante`, que olha o caminho todo e não só a ponta. O quique do morcego sai torto e, sem sair de 1,7 m em 3 s, ele vai pra direção mais aberta (`direcao_livre`). Se encostar em parede volta pro `ultimo_bom`, então nunca sai da casa. Ação nova que mova o fantasma deve usar o helper.
- **Passeio**: com `passeia` (export, ligado em cão, diabrete, geleia, palhaço, criança e zumbi) o fantasma anda devagar por perto no mesmo cômodo (`velocidade_passeio` 0,51 m/s, `raio_passeio` 2,27 m), parando com o mouse em cima (`Fantasma.passear`). `caminho_permitido` recusa rota por cômodo proibido, e quem cair num cômodo proibido sai andando. O cão tem `passeio_casa`: passeia pela casa toda, mais rápido. Quem mexe: `ocupado()`/`ocupada()` param o passeio, `virar_para` é a virada de cada um, zumbi tem `sortear_passeio` e `mover_passeio` próprios (grama). `liberar_recarga` zera a recarga enquanto a ação não aconteceu (arranhão, até a garra descer) ou quando não deu certo (mastigar, lambidão); `segurar_recarga` a enche na hora do golpe.
- **Susto em grupo**: ação com `Acao.em_grupo` (Bater asas, Latido, Quebrar Objetos, Bafo, Risada, Mordida de Fogo) e o clarão da invocação valem mais quanto mais gente pegam: `Fantasma.medo_em_grupo` soma `BONUS_POR_PESSOA` (25%) por pessoa a mais, até `BONUS_MAXIMO` (x2). `Fantasma.sentir_grupo(npcs, centro)`, chamado antes dos sustos, faz o feel com 2 ou mais: `scripts/efeitos/efeito_grupo.gd` (raios até cada pessoa, anéis e faíscas em malha 3D, em tempo real), "N DE UMA VEZ!" e "MEDO Xn", hitstop, tremida, tranco e o sininho mais agudo, tudo crescendo com a quantidade. O objeto levitável fica de fora: ele assusta a sala toda a cada segundo.
- **Mover** (`Fantasma.pode_mover`, ligado em criança, diabrete e palhaço; `recarga_mover`, 30 s): `_enter_tree` acrescenta a ação às `acoes` (por isso não aparece na carta). É uma ação com mira: mostra os quadradinhos de onde pode ficar, pela mesma regra de colocar a carta (`area_jogo.pode_soltar_em` aceita o próprio fantasma), e `mover_para` faz ele sumir numa fumaça e reaparecer.
- **Feel**: ao soltar da loja o fantasma chama `aparecer()` (cresce com overshoot a partir de 30% da escala da cena, fade-in, fumaça e tremida); toda ação bem-sucedida chama `pulinho()` (amassa/estica o sprite); quando uma recarga zera, `piscar(1, 0.08)`. Ação que não deu chama `negar()`, que balança o `offset.x` do sprite (offset, porque geleia e cão mexem em `position`/`rotation` do sprite). O preview do arraste tem 72 px fixos e a `area_jogo` deixa ele avermelhado onde não dá pra soltar. Arrastar um card sem poder comprar chacoalha o card. A tela treme ao subir nível de medo, quebrar objeto, na cabeçada e no balão.

#### Cada fantasma

- **Morcego** (`morcego.gd`): voa quicando nas paredes; `bater_asas()` assusta e empurra pra longe (radial) todo NPC a até `raio_bater_asas` (1,7 m) em volta dele. Pisca 2 vezes (cada uma do tamanho de um quadro do `voar`).
- **Criança Medonha** (`crianca.gd`, Poltergeist): parada, origem no pé. `chorar()` só funciona com exatamente um NPC no cômodo dela (no corredor, a até `raio_choro`, 2,84 m), e sem isso avisa o motivo com uma onomatopeia ("MUITA GENTE!", "NINGUEM AQUI!"); mostra o sprite `lagrimas` por cima.
- **Cavaleiro** (`cavaleiro.gd`, Espectro, `pontos_spawn = "armadura"`, parado): `susto_de_espada()` acerta o NPC mais perto a até `raio_espada` (1,7 m).
- **Cão Possuído** (`cao.gd`, Espectro, `comodos_proibidos = ["quarto"]`): `mastigar()` vai pelo caminho até o NPC mais perto do mesmo cômodo (sem entrar em cômodo proibido; não chegando, devolve a recarga), segura ele com `atordoar` e assusta só ele; `latido_feral()` assusta todo NPC do mesmo cômodo e solta uma onda (`soltar_onda`, anéis em malha 3D, `raio_onda`). Gira o desenho (`sprite.giro`) pra encarar pra onde anda.
- **Diabrete** (`diabrete.gd`, Demônio): `quebrar_objetos()` voa (pelo caminho da navegação) até o nó mais perto do grupo global `quebravel`, dá `reparent` dele pra si no peito, ergue (`altura_levantar`), devolve pro `mundo`, deixa cair e quebra (some, soltando `scene/efeitos/estilhacos.tscn`: cacos + poeira em `GPUParticles3D` one-shot que se libera no `finished`), assustando no máximo `max_assustados` NPCs a até `raio_quebra` (2,5 m) do lugar da queda. Os estilhaços entram em `fase.mundo` e recebem a `global_position` logo depois do `add_child`: o `efeito_unico.gd` só começa a emitir no quadro seguinte, já no lugar certo. Qualquer `Node3D` nesse grupo serve; se tiver `ser_pego()` (como o levitável), o diabrete chama antes de levar. Objeto quebrado fica invisível e fora do grupo `quebravel` por `tempo_reaparecer` (30 s de jogo; pausa e câmera lenta afetam a espera). Depois retorna ao pai, posição, escala, rotação e cor originais e volta ao grupo. O estado original é capturado depois de `ser_pego()` e antes do `reparent`; o tween pertence ao objeto e é encerrado ao sair da cena.
- **Caveira** (`caveira.gd`, Aparição, tier 3, 12 sustos, `mortes_para_liberar = 2`, `pontos_spawn = "lareira"`): `risada_maligna()` assusta todos a até `raio_risada` (2,5 m); `mordida_de_fogo()` pega até `max_mordidos` mais perto, mostra a animação `mordida` (dentes com aura, `mordidaEsqueleto64x64`, `Sprite3D` filho de cada NPC mordido em `posicao_dentes`, escala `escala_dentes`) e chama `Npc.correr_para_outro_comodo()`; `cabecada()` segue o caminho da casa atrás do NPC mais perto por até `tempo_max_perseguindo`, segura ele durante a animação, aplica `atordoar(duracao_stun_cabecada, dreno_cabecada)` e volta pra `casa` (onde estava ao começar a perseguir) pelo mesmo caminho (`voltando`).
- **Palhaço** (`palhaco.gd`, Poltergeist, tier 3, 14 sustos, `mortes_para_liberar = 2`, `comodo_spawn = "quarto"`): flutua (o sprite sobe e desce). `musica_de_circo()` grava `comodo_musica`, entra no grupo `musica` por `duracao_musica` e, enquanto isso, `Fase.intensidade_susto` multiplica por `intensidade_musica` todo susto de NPC naquele cômodo, venha de quem vier. Durante a música ele dança e solta notas (`nova_nota()`, `Sprite3D` com a nota desenhada). O nó `musica` (`AudioStreamPlayer3D`) recebe arquivo e volume do `som.gd` (`preparar`). `balao()` toca `balao` (a spritesheet inteira, último quadro mais longo) e assusta o NPC mais perto do mesmo cômodo a até `raio_balao` (2,84 m) no último quadro, com tremida e um inchaço elástico. O Malabarismo do card ainda não existe.
- **Geleia Roxa** (`geleia.gd`): fica parada, com o sprite balançando de lado em pixels inteiros (`amplitude_balanco`, `velocidade_balanco`). `comer_e_regorfar(onde)` (ação com mira) toca `mordida` e, no fim, solta uma `scene/fantasmas/comida.tscn` (`comida.gd`, `Sprite3D`); quem pisa na comida leva susto, vomita (`atordoar`, `tempo_vomitando`) e a comida vira poça. Quem estiver a até `raio_cheiro` (2,27 m) sente o cheiro e vai até ela (`Npc.ir_comer`, um por vez). `lambidao()` anda pelo caminho até o NPC mais perto do mesmo cômodo (se ele sair, vai atrás de outro; sem ninguém, devolve a recarga), vira, segura a pessoa e no `quadro_lambida` a língua chega: susto mais `direcao_correr`. Os sprites são da `mordida-Sheet.png` e da `lambida-Sheet.png`, desenhados virados para a esquerda, por isso o `flip_h` quando o alvo está à direita.
- **Zumbi** (`zumbi.gd`, Demônio, tier 2, 8 sustos, `fora_de_casa`): fica na grama, de frente pra esquerda no desenho (por isso `flip_h` quando o alvo está à direita). `bafo_do_medo()` assusta todo NPC num círculo de `raio_bafo` (2,5 m) em volta dele (`medo_bafo` e `atordoar(paralisia_bafo)`, mesmo do outro lado da parede) e vira pro mais perto. As nuvens (`nuvens_bafo`, 8) são sprites soltos em `mundo` com a animação `bafo` (sheet separada), saindo em volta dele pra todos os lados, as mais longe aparecendo depois e maiores. `arranhao()` escolhe o NPC mais perto *pelo caminho* (`distancia_andando`, até `alcance_arranhao`) e vai com o `NavigationAgent3D` (camadas 1+2): contorna a casa, entra pela porta e nunca atravessa parede. Na grama anda a `velocidade_fora` (1,7 m/s); dentro da casa, bem devagar (`velocidade`, 0,85 m/s), cambaleando. Desiste depois de `tempo_max_perseguindo`, segura o NPC durante a animação, assusta no `quadro_arranhao` (garra descendo) e volta (`voltando`) pelo mesmo caminho. O bafo continua passando por parede.

### Objeto levitável

`scripts/objetos/objeto_levitavel.gd` (`Node3D` com a malha `malha`): segurar o botão esquerdo sobre o objeto (`fase.mouse_em_malha(malha)`) faz ele levitar e tremer. A cada `intervalo_susto` (1 s) chama `tomar_susto(tipo_susto, pontos_susto)` em todo NPC do grupo `npc` que esteja no mesmo cômodo (`fase.comodo_em`); o primeiro susto de cada vez solta um "BUUU!". Feel: com o mouse em cima sobe `altura_hover`; ao pegar, estica; segurando, a tremida e o balanço crescem até `tempo_carga`; a cada susto `pulsar()` (incha, pisca claro e treme a tela); ao soltar cai quicando (`TRANS_BOUNCE`) e amassa na primeira batida. Hover ou segurando clareia a malha por emissão (`destaque`, `brilho_hover`, `brilho_susto`: vale o maior) e põe a mãozinha no cursor. Entra no grupo `levitavel` no `_ready` e expõe pro tutorial `topo()` e `destaque`.

**Prop destrutível e levitável ao mesmo tempo**: o prop de debug (`scene/objetos/prop_debug_levitavel.tscn`, caixa ciano) tem o script e está no grupo `quebravel`. Quando o diabrete pega, ele chama `ser_pego()`: solta o mouse se o jogador estava segurando, volta pra `posicao_original`, sai do grupo `levitavel` (o tutorial não aponta pra ele) e desliga a interação, então o prop não levita nem recebe clique enquanto está no peito dele; o diabrete derruba e quebra como com qualquer quebrável. Depois de `tempo_reaparecer` (30 s de jogo), `reaparecer()` restaura o mesmo nó no pai e na transformação originais e reativa a levitação e o grupo. O `scene/objetos/objeto_quebravel.tscn` (cilindro laranja) é só quebrável. Na casa são 3 de cada, em `props`.

### Som

`scripts/globais/som.gd` (nó filho do `GameManager`, em `GameManager.som`, `process_mode = ALWAYS`): a tabela `SONS` guarda arquivo (em `assets/sons/`), volume em dB e de onde começa (vários arquivos abrem com silêncio); `MUSICAS` guarda as músicas (menu 0 dB, jogo -7 dB, em loop e com fade na troca). As ações dos fantasmas ficam baixas de propósito (uns -28 dB de volume real, abaixo da música). `tocar(nome, duracao, fade)` é som do mundo: o player fica na cena atual, então pausa com o jogo e some na troca de cena; com `duracao`, para sozinho sumindo nos últimos `fade` segundos (a sirene: 6 s com 2,5 s de fade, junto com a luz). `tocar_ui(nome)` toca com o jogo pausado. `parar(player, fade)` corta um som em andamento (objeto levitável, balão inflando). `gritar()` sorteia um de `assets/sons/sustos/susto1..6.mp3` sem repetir o anterior (cortados de `sustos normais (...).mp3`) e toca quando o NPC sobe de nível sem fugir. O mesmo som não toca mais que `MAX_JUNTOS` (2) vezes junto. Todo `Button` não flat ganha o hover sozinho (`node_added`); a carta é flat e tem som próprio. Som posicional é `AudioStreamPlayer3D`. Tudo é carregado com `load()`: mp3 novo precisa ser importado pelo editor antes. O aviso de `AudioStreamMP3` vazado ao fechar o jogo é intermitente (a música ainda tocando na hora de sair) e não afeta nada.

### Onomatopeias

`scripts/efeitos/onomatopeia.gd` (`class_name Onomatopeia`, `Node2D` de UI presa no mundo): `Onomatopeia.soltar(texto, pos, cor, tamanho)` cria o texto, com `pos` um ponto 3D do mundo, numa fonte pixel 5x7 desenhada no próprio script (letras A-Z, dígitos e ! ? . -, sem acento), com sombra na cor escurecida, que pula, sobe e some. `Fantasma.onomatopeia(texto, cor)` solta em cima do desenho. Cada ação tem a sua (FLAP FLAP, NHAC!, SLURP!, BUAAA!, SHING!, AU AU!, CRASH!, HAHAHA!, POW!, LA LA LA, POP!, HUAAAA, SCRATCH!); também BLERGH! (comida), BUUU! (objeto levitável), AAAH!/SOCORRO! (subir de nível), TUM TUM e PLOFT! (infarto), VUUSH! (invocação) e UIU UIU (polícia).

## Balanceamento

Bem fácil, para a jam. Começa com 5 sustos (`GameManager.SUSTOS_INICIAIS`, dá pra comprar um fantasma barato logo de cara). Alvo: partida de 8+ minutos (um bot com uma decisão a cada 2,5 s leva uns 10 min).

- **Custos**: morcego 3, cavaleiro 3, criança 4, diabrete 4, geleia 7, zumbi 8, cão 8, caveira 12, palhaço 14.
- **Medo** (exports `medo_*` dos scripts): morcego 24, cavaleiro 30, criança 36, diabrete 30, geleia 50 (comida) e 42 (lambida), cão 42 (mastigar) e 22 (latido), zumbi 24 (bafo) e 54 (arranhão), caveira 24, 38 e 66 (risada, mordida, cabeçada), palhaço 36 (balão), invocação 20.
- **Recarga** de cada `Acao` na cena: Bater asas 5, Susto de Espada 6, Chorar 8, Quebrar Objetos 6, Comer e regorfar 8, Lambidão 12, Mastigar 10, Latido Feral 6, Bafo do Medo 12, Arranhão 15, Risada Maligna 10, Mordida de Fogo 14, Cabeçada 20, Música de Circo 14, Balão 5.
- **Objeto levitável**: dá 15 por segundo até o nível 1 e só 3 a partir do nível 2 (`nivel_fraco`, `pontos_susto_fraco`), e nunca expulsa (para em 99 no nível 4).
- **Medo por nível**: `reducao_por_nivel` é 0.05: cada NPC precisa de ~550 pontos para fugir (100, 105, 110, 115 e 120 por nível) e o mesmo tipo de susto seguido conta normal.

## Convenções e cuidados

- Nomes de gameplay ficam em português (`tomar_susto`, `barra_susto`, `nivel_medo`, `fugir`); navegação e motor, em inglês. O código mistura snake_case e camelCase; siga o estilo do arquivo que estiver editando.
- Comentários curtos em português, tom de dev, cabeçalho de 1-2 linhas por arquivo.
- Posição de mundo é sempre `Vector3`. Não crie nó 2D no mundo (`Node2D`, `Sprite2D`, `NavigationServer2D`, `PointLight2D`, `CPUParticles2D`): a exceção é a UI presa no mundo (ver acima), que é `CanvasItem` posicionado por `fase.posicionar`. Nada de `z_index`, `y_sort` ou `show_behind_parent` no mundo.
- Tween de `position`/`scale` funciona com `Vector3`. Tweens que não podem parar na câmera lenta usam `set_ignore_time_scale()`.
- **Tempo real**: coisas que precisam continuar no hitstop ou na câmera lenta (tremida, tranco, hover, realce do menu, tutorial) usam `delta / time_scale` com teto de 0.05; sem o teto, no frame em que o `time_scale` muda o delta vem errado e zera tudo. A câmera lenta (menu de ações, arraste de carta e lore do NPC) entra/sai com o tween de `GameManager.mudar_tempo`, e o `_exit_tree` do menu, do baralho e da lore (se aberta) chamam `GameManager.tempo_normal()`.
- Ao editar `.tscn` à mão, cuidado com os blocos grandes de sub-resources. Exports de nó usam `node_paths=PackedStringArray(...)` no cabeçalho do nó. Posição 3D numa cena é `Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, x, y, z)` ou `position = Vector3(...)`. Use LF e tab.
- Um `float` de 32 bits do Godot (zoom, por exemplo) compara-se com `is_equal_approx`, nunca com `==`.
- Antes de commitar mudança de script/cena, rode `tests/compilar.gd` e `tests/verificar_partida.gd`.
- Desempenho: roda a ~165 FPS (teto do vsync) com sombras, névoa em camadas e desfoque. O desfoque e as sombras das luzes são os candidatos se precisar cortar.

Configuração de tela em `project.godot`: 1920×1080, tela cheia exclusiva (`mode=3`), stretch `canvas_items`/`expand`.
