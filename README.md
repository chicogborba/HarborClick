# HarborClick

Clicker/idle de terminal de contêineres. Mobile, retrato, pixel art top-down.
Godot 4.7 · todos os assets (sprites, fonte, SFX e música) são **gerados por
código**.

O pátio começa vazio. Você toca no navio pra descarregar a importação, depois
embarca a exportação de volta, contrata equipamento, compra terreno — e o
terminal vai enchendo até virar um caos lindo de contêiner empilhado.

## Rodar

Requisitos:

- [Godot 4.7](https://godotengine.org/download/) ou mais recente;
- Git, caso queira clonar o projeto.

Clone e entre na pasta:

```bash
git clone https://github.com/chicogborba/HarborClick.git
cd HarborClick
```

Abra `project.godot` no Godot e pressione **F6/F5**, ou execute pela linha de
comando:

```bash
# macOS
/Applications/Godot.app/Contents/MacOS/Godot --path .

# Linux (se o executável estiver no PATH)
godot --path .

# Windows (PowerShell, ajuste o caminho se necessário)
& "C:\Program Files\Godot\Godot_v4.7-stable_win64.exe" --path .
```

Viewport 320×480 com escala inteira (janela 640×960). A janela é
redimensionável: `stretch/aspect = expand` revela mais terminal em telas
maiores em vez de esticar os pixels.

Touch/mouse: arraste pra rolar o terminal, toque no navio pra movimentar carga,
toque no gato pra um bônus temporário.

Para apenas validar o carregamento do projeto, sem abrir uma janela:

```bash
godot --headless --path . --editor --quit
```

## O ciclo de uma escala

O navio segue a sequência real de uma atracação:

1. **Chega** carregado de importação.
2. **DESCARGA** — cada toque tira uma caixa do convés e ela voa pro pátio.
3. Convés vazio → **EMBARQUE**. Agora cada toque puxa uma caixa do pátio pro
   navio. O lote de exportação é ~45% da capacidade, e é essa assimetria que
   faz o pátio crescer escala após escala.
4. Stow completo → o navio zarpa e o próximo entra.

Enquanto isso, reach stackers e cavalos mecânicos entram pelo portão, correm a
via de serviço, encostam no bloco pela faixa de rolamento e levam contêineres
pra fora do terminal — ou trazem carga de importação. Quanto mais throughput,
mais cheio o pátio fica (`PortWorld.target_fill()`).

## Estrutura

```
assets/
  sprites/     PNGs gerados (não editar à mão — saem de tools/sprites)
  fonts/       fonte pixel BMFont gerada
  audio/       WAVs gerados (tools/audio)
  shaders/     água top-down, névoa
scripts/
  autoload/    EventBus, GameState, TimeManager, SaveManager, AudioManager
  data/        structure_db, upgrade_db, land_db (dados puros)
  world/       port_layout, port_world, ship, container_yard, structure_*,
               ground_baker, atmosphere, critters, port_camera
  ui/          ui_theme, hud, shop, shop_card, tutorial, toast_layer,
               settings_panel, offline_popup
tools/
  venv/        Python + Pillow
  sprites/     geradores de pixel art, fonte e UI
  audio/       synth chiptune + geradores de SFX/música
```

Dois arquivos concentram as decisões:

- **`PortLayout`** — a geometria do terminal (onde é pátio, cais, água, bloco,
  faixa, portão). Qualquer coisa que precise de posição pergunta pra ele.
- **`UiTheme`** — a fonte, os nine-patches e os ícones. Toda tela monta a
  partir dele, então a interface inteira muda de uma vez só.

Profundidade é resolvida por um único nó `Entities` com `y_sort_enabled`:
máquinas, pessoas, postes e pilhas nunca se atravessam. O que de fato voa por
cima (lanças de portêiner, drones, caixas em trânsito) fica em `Overhead`.

## Nomenclatura

Os nomes seguem o jargão de terminal brasileiro: **portêiner** (STS),
**transtêiner** (RTG), **reach stacker**, **empilhadeira de vazios**,
**cavalo mecânico** puxando semirreboque, **berço**, **pátio**, **retroárea**,
**gate**.

## Regenerar assets

```bash
tools/generate_all.sh
```

Roda todos os `tools/sprites/gen_*.py` e `tools/audio/gen_*.py`. Sprites saem em
`assets/sprites/`, e uma versão ampliada 4× vai pra `tools/preview/` só pra
inspeção visual. Depois de gerar, rode o import do Godot **duas vezes** (a
primeira só registra os arquivos novos):

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Paleta compartilhada em `tools/sprites/palette.py`; a paleta da interface fica
separada, em `tools/sprites/gen_ui.py`.

> Cuidado ao desenhar nine-patches: o miolo é **esticado**, então qualquer
> textura ali vira retângulo gigante num painel largo. Miolo sempre chapado.

## Sistemas

- **Economia** — TEUs como moeda, custo `base × 1.15^n`, 15 equipamentos,
  ~18 melhorias, 8 parcelas de terreno, prestígio ("abrir capital" → ações
  douradas com +2% permanente cada).
- **Pátio** — `ContainerYard` guarda o nível de cada slot (3 de altura). Slots
  são **reservados no momento do lançamento**, não na aterrissagem: sem isso,
  caixas em voo colidem no mesmo slot e somem. O navio reserva as células de
  embarque pelo mesmo motivo.
- **Dia/noite** — ciclo de 12 min. `Atmosphere` interpola o tint global, acende
  os postes com flicker ao anoitecer e roda a névoa (15% dos dias) com foghorn.
- **Áudio** — 13 SFX e 3 trilhas longas e calmas (dia/noite/neblina) com
  crossfade. Liga/desliga em Ajustes, persistido em `user://audio.cfg`.
- **Save** — JSON em `user://save.json`, autosave a cada 30s, progresso offline
  (cap 8h, 50% de eficiência) com quadro de boas-vindas.

## Debug

Em build de debug:

- `F2` — screenshot em `user://shot.png`
- `F3` — +1M TEUs
- `F4` — acelera o ciclo dia/noite 40×

Criar um arquivo vazio `.devprobe` na raiz faz o jogo se auto-jogar no boot:
trabalha uma escala inteira (descarga + embarque), compra tudo, expande o
terminal, abre cada aba da loja e os Ajustes, e salva screenshots em
`user://probe_*.png`. Cada expectativa quebrada imprime `[probe] FAIL: ...` no
console. Foi esse probe que pegou os dois bugs de reserva de slot descritos
acima — vale rodar depois de mexer no fluxo de carga.
