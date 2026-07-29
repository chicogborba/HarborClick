# HarborClick

Clicker/idle de terminal de contêineres. Mobile, retrato, pixel art top-down.
Godot 4.7 · todos os assets (sprites, fonte, SFX e música) são **gerados por
código**.

O pátio já nasce com um manifesto de exportação. Você descarrega toda a
importação do navio, embarca um lote diferente até completar o convés, contrata
equipamento, compra terreno — e o terminal vai enchendo até virar um caos lindo
de contêiner empilhado.

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

Viewport-base 320×480 com escala inteira (janela inicial 640×960). A composição
é mobile-first e redimensionável: em retrato o porto ocupa a tela; em 16:9 ele
usa cerca de 68% da largura e deixa um rail de comandos para loja e menus.

Touch/mouse: arraste pra rolar o terminal, toque no navio pra movimentar carga,
toque no gato pra um bônus temporário.

Para apenas validar o carregamento do projeto, sem abrir uma janela:

```bash
godot --headless --path . --editor --quit
```

As suítes determinísticas também podem ser executadas sem janela:

```bash
godot --headless --path . res://tests/core_test_runner.tscn
godot --headless --path . res://tests/cargo_test_runner.tscn
godot --headless --path . res://tests/ui_p0_test_runner.tscn
godot --headless --path . res://tests/phase3_economy_test_runner.tscn
godot --headless --path . --script res://tests/phase3_progression_test_runner.gd
godot --headless --path . res://tests/phase3_progression_ui_test_runner.tscn
godot --headless --path . res://tests/phase4_ship_test_runner.tscn
godot --headless --path . res://tests/phase4_water_test_runner.tscn
godot --headless --path . res://tests/traffic_test_runner.tscn
godot --headless --path . res://tests/notification_test_runner.tscn
godot --headless --path . res://tests/contrast_test_runner.tscn
godot --headless --path . res://tests/a11y_test_runner.tscn
godot --headless --path . res://tests/backup_test_runner.tscn
godot --headless --path . res://tests/profile_test_runner.tscn
godot --headless --path . res://tests/automation_test_runner.tscn
godot --headless --path . res://tests/gate_test_runner.tscn

# cenários de balanceamento (ativo, híbrido, casual, offline e recuperação)
godot --headless --path . --script res://tools/balance/run_balance.gd -- all
```

## O ciclo de uma escala

O navio atual segue esta sequência:

1. **Chega** com 24 contêineres de importação, cada um com UID persistente.
2. **DESCARGA 0/24 → 24/24** — o clique reserva origem e destino; TEU só é
   creditado quando a caixa pousa no setor de importação.
3. Convés vazio e nenhum voo pendente → **AGUARDANDO EXPORTAÇÃO**.
4. **EMBARQUE 0/24 → 24/24** — somente caixas do setor de exportação, com UIDs
   diferentes do manifesto importado, podem subir.
5. O navio parte apenas cheio e com zero transferências em voo.

Salvar no meio de uma transferência é seguro: no reload ela volta à origem,
sem duplicar carga nem pagar a recompensa duas vezes.

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
  autoload/    EventBus, GameState, TimeManager, Progression, SaveManager,
               AudioManager
  cargo/       CargoUnit, transações, controlador de escala e tráfego
  core/        schema e contratos puros de persistência
  data/        structure_db, upgrade_db, land_db, achievements, contratos,
               catálogo de navios e árvore de capital (dados puros)
  economy/     fórmula geométrica, catálogo canônico e simulador determinístico
  progression/ carreira, conquistas, contratos, Diário e persistência
  world/       port_layout, port_world, ship, água/espuma por qualidade,
               container_yard, structure_*, ground_baker, atmosphere,
               skyscape, critters, port_camera
  ui/          ui_theme, port_icon, readout, command_rail, hud, shop,
               shop_card, tutorial, Diário, capital, notification_coordinator,
               toast_layer, settings_panel, offline_popup
tools/
  venv/        Python + Pillow
  sprites/     geradores de pixel art, fonte e UI
  audio/       synth chiptune + geradores de SFX/música
  capture/     harness de screenshot (roda o jogo de verdade em toda a matriz
               de resolução e falha se algum overlay sair do viewport) e
               medição de frame time no cenário de estresse
  export/      build web reproduzível + servidor local com COOP/COEP
tests/         regressão headless: core/save, backup manual, UI, acessibilidade,
               contraste, tráfego, notificações e 100 escalas de carga
```

Dois arquivos concentram as decisões:

- **`PortLayout`** — a geometria do terminal (onde é pátio, cais, água, bloco,
  faixa, portão). Qualquer coisa que precise de posição pergunta pra ele.
- **`UiTheme`** — a fonte, os nine-patches e os ícones. Toda tela monta a
  partir dele, então a interface inteira muda de uma vez só.
- **`TrafficCoordinator`** — quem pode andar e para onde. A via de serviço tem
  duas mãos separadas e cada faixa de rolamento pertence a um veículo por vez;
  sem isso dois caminhões se atravessam ou travam de frente um pro outro.

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

## Exportar

O renderer já é `gl_compatibility` (WebGL2 no navegador), e o preset Web exclui
`tools/`, `tests/` e `.devprobe` — as sondas de desenvolvimento nunca embarcam.

```bash
tools/export/build_web.sh          # importa, roda a regressão inteira, exporta
python3 tools/export/serve_web.py  # serve build/web com COOP/COEP
```

Abrir `index.html` direto do disco **não funciona**: o navegador bloqueia o
fetch do módulo, e sem cross-origin isolation a engine cai num caminho
degradado ou nem inicia. O servidor acima existe só pra mandar os dois
cabeçalhos certos.

Requer os *export templates* da versão do Godot em uso (Editor → Manage Export
Templates). Sem eles o export falha com `No export template found` — foi
exatamente até esse ponto que o preset foi verificado aqui.

Mobile: crie o preset em Editor → Export, aponte o Android SDK/keystore em
Editor Settings e exporte com o mesmo comando trocando o nome do preset. O
ciclo de vida do app já está tratado — `SaveManager` grava de forma síncrona em
`APPLICATION_PAUSED`, `FOCUS_OUT`, `WM_GO_BACK_REQUEST` e `WM_CLOSE_REQUEST`, e
recredita o progresso offline em `APPLICATION_RESUMED` pelo mesmo caminho que
uma inicialização a frio usa.

### Backup do save

Ajustes → **SAVE** → `EXPORTAR` copia o save pra área de transferência e grava
uma cópia em `user://harborclick_save.json`; `IMPORTAR` lê da área de
transferência e pede uma segunda confirmação antes de substituir a run.
Um texto inválido é recusado com o motivo e **não** encosta no save atual
(`tests/backup_test_runner.gd`).

No boot o `SaveManager` sonda se `user://` é gravável. Um navegador que recusa
dados do site — janela anônima, cota cheia — passa a avisar em Ajustes em vez
de deixar o jogador construir uma run que evapora no reload.

### Checklist de release

1. `tools/generate_all.sh` e importar **duas vezes**;
2. `tools/export/build_web.sh` (roda a regressão inteira e falha cedo);
3. `tools/capture/capture.tscn -- matrix` — nenhum overlay fora do viewport;
4. `tools/capture/perf.tscn -- 1920x1080` — p95 dentro de 16,67 ms;
5. `tools/balance/run_balance.gd -- all` — metas de sessão ainda batendo;
6. exportar um save, apagar o progresso, reimportar e conferir que o estado
   volta idêntico;
7. abrir a build servida, recarregar a aba e conferir que o progresso persiste.

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
  Os mastros do cais também acendem enquanto o berço está sendo trabalhado.
- **Céu** — `Skyscape`. De cima não se olha pra cima: nuvem é só a sombra que
  ela joga no pátio, lua e estrelas só o reflexo na água, por baixo do casco.
- **Áudio** — 13 SFX e 3 trilhas longas e calmas (dia/noite/neblina) com
  crossfade. Liga/desliga em Ajustes, persistido em `user://audio.cfg`.
- **Tráfego** — via de serviço de mão dupla separada em duas colunas, faixa de
  rolamento reservada por veículo e distância de seguimento. Um veículo travado
  devolve o serviço em 12 s em vez de segurar a faixa e matar de fome o resto.
- **Notificações** — `NotificationCoordinator` decide o que merece atenção:
  estado rotineiro (fase do berço, chegada) fica só no chip e no histórico,
  repetições dentro de 8 s viram contagem numa faixa só, um toast por vez e no
  máximo um por segundo, prioridade fura fila.
- **Acessibilidade** — foco alcança tudo por Tab/setas, Enter ativa, Escape e
  Back fecham; anel de foco de dois tons; nomes acessíveis em toda tecla de
  ícone. Todo texto funcional passa de 4,5:1, verificado por teste.
- **Portão** — caminhões da cidade estacionam na praça ao lado do gate e são
  clicáveis como o navio. Caminhão carregado é porta de **entrada** com o pátio
  vazio; caminhão vazio é porta de **saída** com o pátio cheio. Sem isso o
  terminal é um ciclo fechado (entra por mar, sai por mar) e um ciclo fechado
  trava.
- **Automação** — portêiner, transtêiner e flutuante movem carga sozinhos no
  berço, pela mesma transação do toque. Uma escala inteira acontece sem um
  toque quando há equipamento; o toque vira empurrão. A partida paga um bônus
  medido em segundos da renda atual.
- **Perfis** — três terminais independentes em `user://profiles/<n>/`. O slot
  é parte do caminho, nunca do payload, então um save exportado de um entra em
  qualquer outro. O `user://save.json` da build antiga vira o perfil 1 sozinho.
- **Save** — envelope JSON v2 por perfil, escrita temporária,
  rotação de backup, recuperação, migração da versão-base e autosave a cada
  30s. Progresso offline tem cap de 8h e 50% de eficiência.

## Debug

Em build de debug:

- `F2` — screenshot em `user://shot.png`
- `F3` — +1M TEUs
- `F4` — acelera o ciclo dia/noite 40×

Para inspecionar a interface sem ficar clicando: o harness de captura roda a
cena real, dirige cada overlay e grava PNGs em `user://uishots/`.

```bash
# uma resolução
/Applications/Godot.app/Contents/MacOS/Godot --path . tools/capture/capture.tscn -- 390x844

# a matriz inteira de QA, redimensionando a janela em tempo de execução
/Applications/Godot.app/Contents/MacOS/Godot --path . tools/capture/capture.tscn -- matrix

# só uma tela
/Applications/Godot.app/Contents/MacOS/Godot --path . tools/capture/capture.tscn -- 1280x720 shop
```

Ele sai com código 1 se qualquer overlay ficar (parcialmente) fora do viewport
em qualquer resolução — foi assim que o diálogo de prestígio foi pego saindo
por cima da tela num telefone de 320×568.

Criar um arquivo vazio `.devprobe` na raiz faz o jogo se auto-jogar no boot:
trabalha uma escala inteira (descarga + embarque), compra tudo, expande o
terminal, abre cada aba da loja e os Ajustes, e salva screenshots em
`user://probe_*.png`. Cada expectativa quebrada imprime `[probe] FAIL: ...` no
console. Foi esse probe que pegou os dois bugs de reserva de slot descritos
acima — vale rodar depois de mexer no fluxo de carga.

---

## Plano de evolução — replanejado em 30/07/2026

Este é o documento vivo de produção do HarborClick. Cada entrega deve atualizar
seu checkbox no mesmo commit da implementação. Um item só recebe `[x]` depois
de funcionar, passar pelos critérios de aceite e ser verificado nas resoluções
afetadas.

- `[x]` concluído e verificado;
- `[ ]` planejado ou em implementação;
- prioridades: **P0** bloqueia a fundação, **P1** forma o jogo principal e
  **P2** amplia retenção/conteúdo.

### Norte do produto

HarborClick deve ser um clicker de porto que parece vivo mesmo parado: cada
toque precisa ter resposta deliciosa, cada número precisa ser legível e cada
novo sistema precisa alterar algo que o jogador consiga ver no terminal.

Os cinco pilares são:

1. **Mobile first, desktop de verdade:** retrato confortável com uma mão e uma
   composição web que usa a tela inteira, não uma faixa de 320 px.
2. **Logística coerente:** contêiner tem identidade, origem e destino; o visual
   representa o estado econômico real.
3. **Próximo objetivo sempre visível:** início rápido, novidades frequentes e
   intervalos que aumentam suavemente em vez de virarem um muro.
4. **Juice com hierarquia:** toque comum, crítico, compra, marco e evento raro
   têm impactos crescentes, sem transformar tudo em notificação.
5. **Polimento antes de volume:** nenhuma rota, skin ou evento entra sem save,
   responsividade, acessibilidade, balanceamento e teste de regressão.

“Mais logarítmico” foi traduzido em **cadência de novidade**: muito rápida nos
primeiros minutos e progressivamente mais espaçada. A produção continua
multiplicativa, como se espera de um idle, mas o simulador impedirá saltos
bruscos de minutos para dias.

### Especificação de UI e responsividade

#### Perfis de tela

**Mobile/retrato**

- composição começa em 320×480, mas usa altura real, safe area e anchors;
- porto ocupa o viewport inteiro;
- placa TEU de 168–196 px de largura e até 48 px de altura no canto superior
  esquerdo;
- engrenagem separada no canto superior direito;
- estado do berço em chip curto: `DESCARGA 18/24`,
  `AGUARDANDO EXPORTAÇÃO` ou `EMBARQUE 10/24`;
- loja como bottom sheet escuro, com scrim, handle, botão X e área rolável
  realmente recortada;
- abas essenciais alcançáveis com o polegar; detalhes longos ficam numa tela
  secundária, não num painel cobrindo todo o porto.

**Desktop/web**

- alvo de composição pixel-perfect 640×360 em 16:9, escalável por inteiros
  quando possível;
- porto recebe aproximadamente 65–72% da largura e pelo menos 90% da altura;
- command rail de 200–224 px lógicos para loja, objetivo fixado e atalhos;
- nenhum overlay usa `PortLayout.WORLD_W` como largura da janela;
- scroll do mouse/pinch controla zoom, drag move a câmera e teclado tem foco
  visível;
- redimensionar ou rotacionar recompõe UI e câmera sem reiniciar.

#### Contador TEU — revisado em 29/07/2026

A placa de 188×48 saiu. Numa tela de telefone ela era o objeto mais barulhento
do jogo e disputava atenção com o próprio porto; um degradê curto no topo do
viewport compra a mesma legibilidade sem peso visual nenhum.

- sem painel: ícone, número e taxa ficam direto sobre o mundo, com contorno;
- os dígitos são **alinhados à esquerda**, então a origem do número é
  invariável por construção e só a borda direita avança para o vazio — mais
  estável do que reservar um slot largo, e sem desperdiçar 170 px de largura;
- a unidade `TEU/s` vive na linha de baixo, junto da taxa, e nunca se move;
- a fonte já possui dígitos monoespaçados; não será trocada só para mascarar
  um problema de layout;
- valor apresentado atualiza no máximo 20 vezes/s, embora a economia continue
  precisa a cada frame;
- o chip do berço se ajusta ao próprio texto em vez de pintar uma barra fixa
  atravessando o porto.

Aceite: ao simular 0→`1e15` e 100 ganhos/s, ícone, origem do número e a linha
de taxa não se movem sequer um pixel (coberto por `ui_p0_test_runner`).

#### O material da interface — revisado em 30/07/2026

A primeira versão da prancheta era desenho certo, execução chapada: dois tons
por superfície, nenhuma sombra entre camadas e um miolo de nine-patch
**esticado**, que obrigava toda superfície a ser cor sólida pra sobreviver a
ser alargada. O resultado lia como diagrama, não como objeto.

Duas regras arrumaram isso:

- **Toda camada joga sombra na de baixo.** Prancheta no mundo, papel na
  prancheta, ficha no papel, prendedor no papel. Sem isso o conjunto fica
  chapado por melhor que cada peça seja.
- **Nada é retângulo de dois tons.** Madeira, aço, papel e cada tecla correm
  rampa de quatro ou cinco passos, e as faces chapadas carregam veio, fibra ou
  risco de escovado.

O miolo do nine-patch agora é **ladrilhado**, não esticado
(`AXIS_STRETCH_MODE_TILE`), que é o que permite o papel ter fibra e pauta de
verdade.

O que se vê: madeira com veio e cantoneiras de aço rebitadas; prendedor de mola
cromado de 72px com pega serrilhada; papel pautado com fibra; fichas com borda
picotada e sombra própria; teclas com face iluminada, saia sombreada e sombra
projetada; ardósia virou placa de aço parafusada. E um lápis de carpinteiro
largado no papel em branco — ornamento, e vale: prancheta só com linhas
impressas lê como formulário, com um lápis atravessado lê como coisa que
alguém acabou de segurar.

#### Loja, ajustes e overlays — revisado em 29/07/2026

A superfície roxo-marinho desenhada em tempo de execução foi substituída. Ela
era `StyleBoxFlat`: cantos com antialiasing fora da grade de pixel, uma única
cor chapada para todo propósito e nenhuma relação com a arte do jogo — parecia
um painel web flutuando sobre o porto.

- **tudo é a prancheta do conferente**: madeira gasta, prendedor de aço, papel
  de manifesto. Só nine-patches na grade de pixel, gerados por
  `tools/sprites/gen_ui.py`, então a interface inteira muda de um arquivo só;
- números ficam carimbados em ardósia escura, nunca soltos sobre o papel;
- os dois únicos acentos saturados são âmbar (ação) e teal (serviço) — os
  mesmos que as máquinas usam no pátio;
- no mobile, tocar no scrim, arrastar para baixo, apertar Back/Escape ou X
  fecha a loja;
- no desktop, a loja vira drawer/rail e não cobre o porto sem necessidade;
- o backdrop consome o evento: fechar a loja jamais toca no navio atrás;
- cards compram no release e cancelam a ação depois de drag;
- gear com alvo mínimo de 44 px, ícone centralizado opticamente com tolerância
  de 1 px, hover/pressed/focus e nome acessível;
- ajustes, offline, tutorial e prestígio usam backdrop `full_rect`, centro real
  do viewport e devolução de foco ao fechar.

#### Notificações — revisado em 30/07/2026

Nada fica permanentemente sobre o porto. O chip de objetivo morava no canto
superior a sessão inteira e cobria o cais; no desktop o rail já carrega a meta,
e no retrato a tecla DIÁRIO está ali. O único momento que ganha faixa agora é
uma **conquista de verdade sendo cumprida**, e a faixa encolheu.

#### Notificações e conquistas

- chegada e mudança de fase ficam no chip do berço, não em toast — implementado
  em `NotificationCoordinator.ROUTINE_KINDS`;
- apenas um toast visível no mobile e no máximo um novo por segundo;
- eventos simultâneos são agrupados, mas cada ocorrência fica no histórico;
- notificação passa a ter tipo, prioridade, ícone, deduplicação, duração e
  ação;
- “Diário do Porto” terá abas **Próximas**, **Todas** e **Concluídas**, com
  valor/meta, barra e recompensa;
- uma conquista pode ser fixada no HUD como próximo objetivo;
- retorno offline usa um resumo único com tempo ausente, eficiência, limite e
  ganhos.

#### Matriz mínima de QA visual

Automatizada em `tools/capture/capture.gd -- matrix`: o harness sobe a cena
real, redimensiona a janela viva entre as passagens (o que já é o teste de
resize) e falha se qualquer overlay ficar fora do viewport.

- [x] 320×568 — telefone compacto;
- [x] 360×800 — Android alto;
- [x] 390×844 — iPhone moderno;
- [x] 412×915 — Android largo;
- [x] 768×1024 — tablet retrato;
- [x] 1280×720 — web/notebook 16:9;
- [x] 1920×1080 — desktop 16:9;
- [x] rotação e resize em runtime;
- [ ] mouse, touch, teclado e gesto de drag sem ações atravessando overlays —
      touch e mouse cobertos por `ui_p0_test_runner`; teclado só na Fase 7.

### Verdade logística — revisada em 30/07/2026

A divisão em setores de importação e exportação era um **portão**: só uma caixa
marcada EXPORT podia embarcar. Na prática isso trancava o terminal — o pátio
podia estar cheio e o berço parado esperando carga que estava a dez metros.

A regra agora é a de um terminal de verdade: **tudo que está no pátio pode
sair**, menos as caixas que este mesmo casco acabou de descarregar. O que
chegou num navio parte no próximo. Os setores continuam existindo como
preferência de pouso, que é pra isso que serviam.

### Nova verdade logística

O jogo não deve fingir logística enquanto a economia acontece em paralelo.
Esta será a fonte de verdade:

```text
ROTA gera escala
  → navio chega com manifesto de IMPORTAÇÃO
  → jogador/automação descarrega 100% no setor de importação
  → navio aguarda todas as caixas em voo
  → pátio reserva manifesto diferente no setor de EXPORTAÇÃO
  → jogador/automação carrega 100%
  → navio aguarda todas as caixas em voo
  → recompensa é confirmada
  → navio parte cheio
```

Componentes:

- `CargoUnit`: `uid`, tipo `IMPORT/EXPORT`, cor, origem, destino, rota, tier e
  valor;
- `ImportZone` e `ExportZone`: divisão funcional com sinalização visual
  discreta;
- `BerthCallController`: estados `ARRIVING`, `DISCHARGING`,
  `WAITING_EXPORT`, `LOADING` e `DEPARTING`;
- reservas transacionais de origem/destino e contagem de caixas em voo;
- `TrafficCoordinator`: faixas de mão única, distância mínima, reserva de
  segmento e job por UID;
- `ShipCatalog`: feeder, coastal e Panamax inicialmente, cada um com
  capacidade, tamanho, velocidade, hitbox, paletas e multiplicador;
- `RouteCatalog`: decide origem/destino, pool de navios, duração, valor e mix de
  carga;
- `WorldEventDirector`: eventos usam proxies visuais e nunca corrompem o
  inventário real.

Um save novo nasce com um manifesto completo no setor de exportação. Portanto,
a primeira cena já tem contêineres, o primeiro navio consegue descarregar,
carregar completamente e partir sem um tutorial artificial.

### Metas de progressão

| Momento | Meta de experiência |
|---|---|
| 0–10 s | Primeiro toque compreendido e recompensado |
| até 30 s | Primeira renda passiva |
| até 60 s | Primeira escolha real entre duas compras |
| até 5 min | Pelo menos três desbloqueios visualmente diferentes |
| primeira hora | Novidade significativa a cada 2–5 min no início, ampliando suavemente |
| 60–120 min ativos | Primeiro prestígio possível e desejável |
| primeiro dia casual | Primeiro prestígio mesmo com sessões curtas |
| após prestígio | Recuperar o pico anterior 3–5× mais rápido |
| toda sessão | Próximo objetivo e estimativa de progresso visíveis |

O simulador deve testar sessões ativas, híbridas e offline. Comprar a opção
“errada” pode ser menos eficiente, mas nunca deve condenar a run.

### O que já está entregue

Fases 0 a 4 e a metade entregável da 7 estão fechadas e cobertas por teste.
Em vez de manter a lista antiga item a item, o resumo:

- **Fundação** — save v2 atômico com backup, recuperação e migração; export e
  import manual do save; detecção de storage indisponível; `ResponsiveShell`
  com perfis retrato/paisagem; 13 suítes headless; harness de captura que roda
  a matriz de resolução inteira e falha se um overlay vazar do viewport.
- **Carga** — `CargoUnit` com UID persistente, setores de importação e
  exportação, `BerthCallController` com ciclo 100%→0%→100%, recompensa só no
  commit, reservas transacionais e 100 escalas automatizadas sem UID duplicado.
- **Economia e carreira** — simulador de balanceamento, compras x1/x10/x25/MAX,
  upgrades para as 15 estruturas, ~35 conquistas, Diário do Porto, contratos e
  prestígio com árvore de capital.
- **Porto vivo** — variantes de casco persistidas, água por qualidade, sombra
  de nuvem, reflexo noturno, boias de canal, sinalização de setor no chão e
  detalhes ligados ao estado real do berço.
- **Tráfego** — via de serviço de mão dupla, faixa reservada por veículo,
  distância de seguimento e destravamento por timeout.
- **Interface** — a prancheta do conferente: nine-patches na grade de pixel,
  contador sem placa, loja reconstruída, notificações com política única.
- **Acessibilidade** — foco por teclado em tudo, anel de foco de dois tons,
  nomes acessíveis, contraste AA verificado por teste.

O que segue é o que **falta**, reordenado depois do playtest de 30/07/2026.

### Diagnóstico do playtest — 30/07/2026

| Sintoma relatado | Causa | Fase |
|---|---|---|
| "O menu de ações está quebrado, o scroll fica na frente" | A barra de rolagem é desenhada por cima dos cards em vez de reservar largura | A |
| "O botão de configurações está horrível, o de abrir a loja também" | O rail de comandos de desktop nunca foi construído: sobrou um vazio cinza de 32% da tela com dois botões soltos flutuando nele, ainda no estilo antigo | A |
| "Não existe mapa-múndi nem comprar rotas" | Fase 5 nunca foi iniciada | F |
| "Quero menu inicial com 3 perfis" | Não existe tela inicial; o jogo entra direto num save único | B |
| "As máquinas deviam descarregar o navio sozinhas" | Nada além do toque move carga do navio; a automação comprada só enche o pátio | D |
| "Falta um bônus quando o navio vai embora" | A partida não paga nada além do que já foi creditado por caixa | D |
| "Queria vários navios no porto, aparecendo aos poucos" | Existe exatamente um berço e um navio | C |
| "Queria navios de tamanhos e cores diferentes, pequenos no início" | O catálogo tem silhuetas e paletas, mas capacidade fixa em 24 e nenhuma relação com o tamanho do porto | C |
| "O barco entra e sai de ré" | `Ship` interpola posição sem nunca girar o casco | E |
| "As máquinas parecem mover coisas sem sentido" | Os haulers teleportam pro portão, andam em velocidade constante e viram em 90° secos | E |

### Fase A — o rail de comandos e o resto do cromo — P0

O desktop é o pior estado do jogo hoje: um terço da tela é cinza vazio.

- [x] Criar `CommandRail`: prancheta fixa na lateral direita em paisagem, com
      contador, chip do berço, objetivo fixado, teclas e um resumo (dia,
      escalas, ocupação do pátio) preenchendo o pé do quadro.
- [x] Em retrato, as mesmas teclas viram uma barra inferior no mesmo material.
- [x] A loja e o Diário abrem **dentro** do rail no desktop, no mesmo
      retângulo, então parece o rail virando página e não uma gaveta chegando
      de fora.
- [x] Reservar a largura da barra de rolagem (`SCROLL_MODE_RESERVE`) em vez de
      desenhá-la por cima do conteúdo, e trocar a tábua de madeira chapada por
      calha funda com pega arredondada.
- [x] Corrigir a sobreposição entre a taxa do contador e o chip do berço.
- [x] Barra de progresso do Diário com altura de barra, não de sublinhado.

Aceite: em 1280×720 e 1920×1080 não sobra nenhuma área sem função; nenhuma
lista desenha a barra de rolagem sobre um card; a matriz de captura continua
limpa.

### Fase B — tela inicial e perfis — P0

- [x] Cena `Title` como cena principal: título, três lugares de perfil e o
      aviso de storage indisponível quando é o caso.
- [x] Cada lugar mostra TEU de carreira, dia e reconstruções, ou "terreno
      livre".
- [x] Criar, entrar, e apagar com confirmação de duas etapas — e o segundo
      toque só confirma o **mesmo** terminal que foi armado.
- [x] `SaveManager` passa a escrever em `user://profiles/<n>/save.json`, com
      backup e recuperação por perfil.
- [x] Voltar ao menu por Ajustes, salvando antes (a troca de cena derruba os
      provedores de seção, então um snapshot posterior sairia vazio).
- [x] Migrar o `user://save.json` existente para o perfil 1 na primeira
      execução, sem perder nada.

Aceite: três perfis independentes; apagar um não toca nos outros; um save
antigo aparece intacto no perfil 1; reabrir o jogo volta pro menu.

### Fase C — frota: vários navios, classes e cadência — P1

- [ ] `PortLayout` ganha berços múltiplos; o segundo e o terceiro são
      destravados por marcos de terreno.
- [ ] `ShipCatalog` passa a ter classes com capacidade real crescente —
      **feeder 8 → coastal 16 → panamax 24 → post-panamax 40** — com casco,
      largura e paleta próprios.
- [ ] A classe sorteada depende do tamanho do porto: no começo só feeder;
      navio grande é um evento visível.
- [ ] `FleetDirector` agenda chegadas, mantém uma fila de espera fora do porto
      quando todos os berços estão ocupados, e persiste a fila.
- [ ] Cada berço tem seu próprio `BerthCallController` e seu próprio chip de
      estado no HUD.

Aceite: com um berço o jogo se comporta como hoje; com três, três navios são
trabalhados em paralelo sem misturar manifesto; salvar e reabrir reconstrói
exatamente a mesma frota.

### Fase D — automação e recompensa de partida — P1

- [x] Portêiner, transtêiner e guindaste flutuante passam a mover carga de
      verdade: cada um contribui com movimentos por segundo, com teto pra não
      virar borrão. Automação chama **a mesma transação** que o toque, então
      existe um único caminho capaz de criar ou destruir um UID.
- [x] O toque continua valendo — empurrão instantâneo por cima da automação.
- [x] O HUD mostra a taxa automática do berço ao lado da fase.
- [x] Bônus de partida precificado em **segundos da renda do próprio porto**,
      não num número fixo que é enorme na primeira hora e invisível na
      terceira. Entra como recompensa de carreira, então não encurta a curva de
      prestígio contra a qual o simulador foi balanceado.
- [x] Escala com convés completo paga +35%.

Aceite: com equipamento suficiente uma escala inteira acontece sem um toque; o
bônus de partida nunca passa de uma banda definida da CPS; o simulador continua
cumprindo as metas de sessão.

### Fase E — polimento de movimento — P1

- [x] O navio entra de proa e sai de proa. O casco é desenhado com a proa pra
      cima, então só existe um rumo em que ele navega de frente: o canal corre
      **sul → norte** passando pelo cais. Antes era interpolado pra baixo nas
      duas pontas — ré pra atracar e ré pra sair.
- [x] As boias saíram do canal: viraram marcas laterais desenhadas **por cima**
      do casco, então o navio passa por trás delas em vez de atropelá-las.
- [ ] Rebocadores acompanham a manobra de atracação e desatracação.
- [ ] Haulers entram pelo portão dirigindo, com aceleração, desaceleração e
      curva em arco em vez de virada de 90° seca.
- [ ] Cada viagem tem um alvo legível: o veículo para na pilha, o spreader
      desce, a caixa muda de dono, e só então ele sai.
- [ ] Estivadores param ao lado do que estão conferindo.

Aceite: gravar 30 s do pátio e nenhum veículo anda de lado, de ré, ou pára no
meio do nada.

### Fase F — mapa-múndi e rotas — P2

- [ ] Mapa estilizado com o porto no centro e destinos ao redor.
- [ ] Rota comprável com origem, destino, ETA, classe de navio, valor e mix de
      carga; a rota alimenta as chegadas da Fase C.
- [ ] Trade-offs: curta e estável, longa e valiosa, arriscada com eventos.
- [ ] Uma rota nova muda o navio ou o ganho visível em até duas escalas.
- [ ] Integrar ETA ao progresso offline.
- [ ] Coleção de pinturas de casco e bandeiras ligada a rotas e conquistas.

Aceite: comprar uma rota muda o mundo dentro de duas escalas; trocar de rota
não perde nem duplica manifesto; o mapa é usável com uma mão.

### Fase G — eventos raros — P2

Inalterada em relação ao plano anterior: scheduler determinístico com cooldown,
pity e seed; Golden Ship; OVNI sobre proxy visual; baleia, tempestade, regata e
inspeção aduaneira; nada que bloqueie o berço, corrompa carga ou puna offline.

### Fase H — fechamento — P1

- [ ] Medir 60 FPS num aparelho móvel real.
- [ ] Testar pause/background/resume em Android e iOS.
- [ ] Rodar a build web e confirmar persistência de `user://` no navegador.
- [ ] Página web/PWA.

### Definition of Done de qualquer feature

Uma feature só pode ser marcada como concluída quando:

1. regra e estado persistido têm uma fonte de verdade;
2. caminho feliz, limites e reload possuem teste;
3. touch, mouse e teclado não disparam ações involuntárias;
4. telas afetadas passam pela matriz responsiva;
5. feedback visual/sonoro tem hierarquia e opção de reduzir movimento;
6. performance foi medida no cenário de estresse relevante;
7. save antigo migra ou recebe fallback explícito;
8. texto, números e contraste continuam legíveis;
9. documentação e checkbox são atualizados no mesmo commit.

### Ordem de execução

A → B → D → E → C → F → G → H.

O cromo quebrado e a falta de tela inicial são o que o jogador vê primeiro, e
automação com bônus de partida é o que muda o jogo com menos código. A frota
múltipla (C) vem depois do polimento de movimento (E) de propósito: não faz
sentido multiplicar por três um navio que ainda atraca de ré.
