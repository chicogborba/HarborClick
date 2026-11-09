# HarborClick

Clicker/idle de terminal de contêineres. Mobile, retrato, pixel art top-down.
Godot 4.7 · os assets (sprites, fonte, SFX e música) são **gerados por código**,
com uma exceção declarada: três ilustrações da tela inicial — o brasão, o navio
atracado e as três fotos de berço — saem de um modelo de pixel art, e as
respostas dele ficam versionadas junto da receita
(`tools/sprites/pixellab/`). O build nunca chama a API.

O pátio já nasce com um manifesto de exportação entregue pelo comboio rodoviário
inaugural antes do primeiro turno. Você descarrega toda a importação do navio,
embarca esse lote diferente até completar o convés, contrata equipamento,
compra terreno — e o terminal vai enchendo até virar um caos lindo de
contêiner empilhado.

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
godot --headless --path . res://tests/relay_test_runner.tscn
godot --headless --path . res://tests/notification_test_runner.tscn
godot --headless --path . res://tests/contrast_test_runner.tscn
godot --headless --path . res://tests/a11y_test_runner.tscn
godot --headless --path . res://tests/backup_test_runner.tscn
godot --headless --path . res://tests/profile_test_runner.tscn
godot --headless --path . res://tests/automation_test_runner.tscn
godot --headless --path . res://tests/gate_test_runner.tscn
godot --headless --path . res://tests/wake_test_runner.tscn

# cenários de balanceamento: ativo, híbrido, casual, noite fora, build errada
# e recuperação pós-prestígio
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
via de serviço e encostam no bloco pela faixa de rolamento. Toda coleta protege
um manifesto operacional de 24 caixas: abaixo da meta o caminhão traz 2 e leva
no máximo 1; acima dela troca 1 por 1. Portanto, a estrada nunca drena o porto.

Todo veículo é desenhado de nariz pra cima, então norte é rotação zero — o eixo
vertical estava invertido e a frota inteira subia e descia o pátio de ré, o
rebocador incluso.

## Estrutura

```
assets/
  sprites/     PNGs gerados (não editar à mão — saem de tools/sprites)
  fonts/       fonte pixel BMFont gerada
  audio/       WAVs gerados (tools/audio)
  shaders/     água top-down, névoa
landing/       página pública responsiva nos mesmos nove idiomas do jogo;
               apresenta o porto e leva a /jogar/ (ver landing/README.md)
scripts/
  autoload/    EventBus, GameState, TimeManager, Progression, SaveManager,
               AudioManager
  cargo/       CargoUnit, transações, escala, portão, política rodoviária
               pura e coordenação de tráfego
  core/        schema e contratos puros de persistência
  data/        structure_db, upgrade_db, land_db, achievements, contratos,
               catálogo de navios e árvore de capital (dados puros)
  economy/     fórmula geométrica, catálogo canônico e simulador determinístico
  progression/ carreira, conquistas, contratos, Diário e persistência
  world/       port_layout, port_world, ship, água/espuma por qualidade,
               container_yard, structure_*, ground_baker, atmosphere,
               skyscape, critters, port_camera
  ui/          ui_theme, port_icon, readout, rate_breakdown, command_rail, hud,
               shop, shop_card, tutorial, Diário, capital,
               notification_coordinator, notice_bell, npc_card, settings_panel,
               offline_popup
tools/
  venv/        Python + Pillow
  sprites/     geradores de pixel art, fonte, UI e o mapa-múndi da carta
    pixellab/  receitas + respostas cacheadas das três ilustrações geradas
  audio/       synth chiptune + geradores de SFX/música
  capture/     harness de screenshot (roda o jogo de verdade em toda a matriz
               de resolução e falha se algum overlay sair do viewport) e
               medição de frame time no cenário de estresse
  docs/        gerador do mapa completo do código
  fonts/       baixa e conserta os subsets de fonte que a landing hospeda
  qa/          documentação fresca + import + todas as suítes em um comando,
               e o fotógrafo da landing (CDP, métricas de aparelho de verdade)
  export/      build do jogo, pacote landing + /jogar e servidor com COOP/COEP
tests/         regressão headless: core/save, backup manual, UI, acessibilidade,
               contraste, tráfego, notificações e 100 escalas de carga
```

Alguns arquivos concentram as decisões:

- **`PortLayout`** — a geometria do terminal (onde é pátio, cais, água, bloco,
  faixa, portão). Qualquer coisa que precise de posição pergunta pra ele.
- **`UiTheme`** — a fonte, os nine-patches e os ícones. Toda tela monta a
  partir dele, então a interface inteira muda de uma vez só.
- **`TrafficCoordinator`** — quem pode andar e para onde. A via de serviço tem
  duas mãos separadas e cada faixa de rolamento pertence a um veículo por vez;
  sem isso dois caminhões se atravessam ou travam de frente um pro outro. Num
  cruzamento os dois veem o outro pela frente e travariam juntos pra sempre,
  então o desempate é fixo: passa quem tem o menor id de instância.

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
`tools/`, `tests/`, `landing/` e `.devprobe` — fontes da página pública e sondas
de desenvolvimento nunca embarcam dentro do PCK do jogo.

```bash
tools/export/build_web.sh          # importa, roda a regressão inteira, exporta
python3 tools/export/serve_web.py  # serve build/web com COOP/COEP
```

Abrir `index.html` direto do disco **não funciona**: o navegador bloqueia o
fetch do módulo, e sem cross-origin isolation a engine cai num caminho
degradado ou nem inicia. O servidor acima existe só pra mandar os dois
cabeçalhos certos.

### Deploy automático

O código público inteiro está neste repositório: a landing fica em `landing/`,
o jogo Godot fica na raiz e `tools/export/build_release.sh` monta os dois em um
único release (`/` e `/jogar/`). Todo push na branch `main` dispara
`.github/workflows/deploy-production.yml`: a Action testa, exporta e publica na
VPS com troca atômica, mantendo a versão anterior disponível para rollback.
Detalhes operacionais ficam em `deploy/README.md`.

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

- **Idiomas** — português do Brasil, inglês, espanhol, francês, alemão,
  italiano, russo, polonês e turco: os nove mercados que concentram a maior
  parte da base instalada de jogos mobile fora do bloco chinês/árabe/hindi
  (ver limite abaixo). Uma instalação nova lê `OS.get_locale()` e escolhe
  sozinha; a escolha explícita fica em `preferences.cfg` (`language`), e
  "automático" é um estado salvo, não a ausência de um. As strings vivem em
  `scripts/i18n/strings_*.gd`, uma linha por chave e uma coluna por idioma, e
  `Loc.t("chave", {"slot": valor})` é a única forma de pedir texto. Trocar de
  idioma é ao vivo: `Loc.language_changed` reescreve as telas abertas, porque
  exigir reinício seria um bug que o jogador não tem como entender.
  `Loc.tn()` só sabe separar "um" de "outros" — russo e polonês têm uma
  terceira forma (contagem 2-4) que cai em "outros"; é uma lacuna conhecida,
  não descuidada, e some sozinha se o jogo um dia trocar de motor de plural.
  `tests/i18n_test_runner.gd` reprova o build se uma chave ficar sem idioma, se
  um `{slot}` sumir numa tradução, se algum caractere traduzido não existir na
  fonte, ou se uma etiqueta traduzida não couber na faixa de abas da loja ou na
  linha de idiomas dos ajustes — foi exatamente essa checagem que pegou "AUTO"
  virando "AU" mudo no dia em que o nono idioma entrou.
  - **O limite é a fonte, não a vontade.** A interface inteira é uma fonte
    bitmap de células 5×7 (`tools/sprites/gen_font.py`), e latim + cirílico
    cabem nela como letra-base mais um acento — foi assim que russo entrou:
    66 glifos novos, nenhum redesenho do resto. Chinês, japonês e coreano
    precisam de um caractere Han legível por célula, o que pede uma tela bem
    maior e milhares de glifos em vez de um punhado de acentos sobre 26
    letras — não é uma extensão desta fonte, é outro pipeline. Árabe pede
    texto da direita para a esquerda com ligadura contextual entre letras, que
    este renderizador não tem caminho nenhum para fazer. Tailandês e hindi
    empilham vários diacríticos por letra, dos dois lados, de um jeito que a
    faixa de duas linhas de acento deste formato não expressa. Nenhum desses
    é "faltou traduzir" — é um sistema de fonte diferente, e fica para depois
    de decidir se vale trazer uma fonte real para esses scripts (quebrando a
    regra de "tudo gerado por código") ou não.
- **Economia** — TEUs como moeda, custo `base × 1.15^n`, 15 equipamentos,
  ~50 melhorias em árvore, 8 parcelas de terreno, prestígio ("abrir capital" →
  ações douradas com +2% permanente cada).
- **A árvore de melhorias** — as melhorias não são uma prateleira, são um grafo
  em seis troncos (mão de obra, pátio, cais, ramal, portão, comando). Um nó diz
  o que o abre (`requires`), alguns se excluem (`excludes`, ou `group` para uma
  escolha de N vias), e três tipos fazem mais do que multiplicar: `synergy` paga
  por unidade de uma máquina *diferente*, `transform` tira a máquina da produção
  e a põe para reger o porto, e `rail_stat` mexe num botão do ramal. Os cinco
  nós `group: "conductor"` são a mesma pergunta — *quem manda neste terminal* —
  e só um pode estar montado por vez.
- **E é desenhada como mapa de linhas** ([`upgrade_map.gd`](scripts/ui/upgrade_map.gd)).
  A primeira versão da aba era uma coluna de cartas: todo nó estava lá e toda
  tranca era explicada por escrito, e ainda assim era lista. Lista responde *o
  que está no meu caminho*; só desenho responde *para onde isso vai*. Então a
  aba é um diagrama de rede, do jeito que o próprio assunto do jogo desenha uma
  rede: cada tronco é uma linha colorida correndo de oeste para leste, cada
  melhoria é uma estação nela, profundidade é distância ao longo da linha — "três
  paradas adiante" é literalmente três compras adiante. Linha comprada é trilho
  sólido; linha não comprada é traçado tracejado com as estações apagadas. Nó que
  exclui um irmão vira estação de baldeação (anel dentro do ponto). Arrasta para
  andar, pinça para aproximar, toca numa estação e o bilhete embaixo responde
  preço, efeito e o que falta. O mapa inteiro é um `_draw()` num Control só —
  cinquenta estações feitas de Controls seriam cinquenta layouts, e a aba se
  atualiza aberta.
- **Terreno é o portão da escada** — cada parcela **abre uma máquina**: Pátio
  Norte abre o reach stacker, Pátio Sul o transtêiner, Retroporto o armazém,
  Área Ferroviária o trem, Aterro Leste o flutuante, Zona Franca a alfândega,
  Ilha Artificial o porto de IA, Porto Orbital o portal. Antes terreno era dreno
  puro — oito parcelas de até noventa trilhões que compravam vagas de pátio que
  o jogador em geral tinha sobrando, a única compra do jogo que um jogador
  guloso fazia bem em nunca fazer. Cada parcela custa menos que a máquina que
  abre, então o portão é uma decisão de *quando*, nunca um muro; as três
  primeiras máquinas não têm portão nenhum. O capataz nunca compra terreno: uma
  ordem permanente que redesenha o terminal sozinha é a única compra que o
  jogador teria razão de detestar.
- **Pátio** — `ContainerYard` guarda o nível de cada slot (3 de altura). Slots
  são **reservados no momento do lançamento**, não na aterrissagem: sem isso,
  caixas em voo colidem no mesmo slot e somem. O navio reserva as células de
  embarque pelo mesmo motivo.
- **Dia/noite** — ciclo de 12 min. `Atmosphere` interpola o tint global, acende
  os postes com flicker ao anoitecer e roda a névoa (15% dos dias) com foghorn.
  Os mastros do cais também acendem enquanto o berço está sendo trabalhado.
  Onde cada mastro fica é geometria, não sorteio: `PortLayout.lamp_spots()` põe
  dois no portão, um em cada vão entre vagas, e daí uma grade — cada runway de
  transtêiner e a costura do cais, em faixa sim, faixa não. Nenhum cai em cima
  de bloco, de vaga ou no meio da pista.
- **Água** — o rastro do navio é calculado no shader a partir do casco (centro,
  meia-medida e velocidade), não é sprite arrastado atrás do barco: abre em V
  com a distância à popa, rola, e morre quando as máquinas param. Mais uma
  linha quebrada de espuma onde a água encontra o cais.
- **Céu** — `Skyscape`. De cima não se olha pra cima: nuvem é só a sombra que
  ela joga no pátio, lua e estrelas só o reflexo na água, por baixo do casco.
- **Áudio** — 17 SFX e 3 trilhas longas e calmas (dia/noite/neblina) com
  crossfade. Liga/desliga em Ajustes, persistido em `user://audio.cfg`.
- **Ramal ferroviário** — a terceira porta do terminal, e a única que não pode
  dar meia-volta. O corredor é um **fundo de saco**: `GroundBaker` põe lastro,
  dormentes, dois trilhos e um para-choque do limite oeste até `WATER_X0 - 11`,
  e depois disso é cais e mar. Uma composição entra do interior carregada de
  caixas que o interior está exportando — identidades criadas fora do mapa,
  como no manifesto de um navio —, encosta antes do para-choque e é trabalhada
  ali: toque num vagão, ou deixe o **pórtico ferroviário** (o que se compra como
  *Ramal Ferroviário*) percorrer a composição e fazer isso sozinho. O que sai
  do pátio pelo trem passa pelo mesmo caminho protegido do portão, com o mesmo
  piso de estoque, então o ramal nunca deixa o próximo navio sem carga.
  Para sair, a locomotiva **faz a manobra de contorno**: desengata, avança além
  do AMV leste, cruza para a linha de contorno, volta a oeste ao lado da própria
  composição, cruza de novo e engata no que era a cauda. A versão anterior
  espelhava o sprite — a locomotiva se teletransportava para a outra ponta.
  `tests/rail_test_runner.gd` falha se ela não usar a linha de contorno, se
  trabalhar uma composição em movimento, se criar carga no ramal ou se um
  serviço não terminar sem ninguém desenhando o trem.
- **Sinalização do ramal** — sinal de três aspectos na entrada (verde, amarelo
  quando um serviço foi aceito ou está em movimento, vermelho com o trecho
  ocupado), passagem de nível que pisca enquanto há trem na linha, e a placa do
  ramal. Tudo lê o estado do serviço, então nada no chão pode anunciar algo que
  o ramal não está fazendo.
- **Ordem permanente do ramal** — a quarta, ao lado da gangue, da rota e do
  capataz. `EQUILÍBRIO` segue o pátio; `ABASTECER` traz a composição cheia e
  leva o mínimo, e o estoque sobe na velocidade de um trem; `ESCOAR` trabalha
  todo vagão nos dois sentidos, o dobro de movimentos pelo mesmo horário
  reservado. A ordem enviesa a troca e **não pode quebrá-la**: `DRAIN_FILL` é
  lido antes da ordem, então um pátio travado sempre recebe o serviço que o
  destrava — uma ordem capaz de desligar isso seria um jeito de inutilizar o
  save. Ela vale para o *próximo* serviço: horário reservado não se renegocia
  com o trem já na linha.
- **O ramal se anuncia** — ele corre na borda inferior do mundo, abaixo da
  última fileira de galpões, e a câmera não vai atrás. Então avisa: quando um
  serviço é aceito, quando encosta (com quantos vagões descarregar e embarcar),
  e quando parte. Uma composição trabalhada até o último vagão paga bônus de
  conclusão, contado sobre transferências efetivadas — nunca sobre toques. O
  painel de ordens da loja é o instrumento do ramal: mostra o que a linha está
  fazendo agora, porque escolher uma ordem sem poder ver o resultado não é
  decisão nenhuma.
- **A estação** — o ramal não é dois trilhos num asfalto vazio. Ao sul da linha
  corre a **plataforma de carga**: concreto lançado em panos, coping claro na
  borda onde o vagão encosta, linha amarela de segurança, e quatro **rampas**
  hachuradas onde uma carreta encosta na altura do estrado. Na cabeceira, junto
  ao para-choque onde a cabeça de toda composição para, fica o **galpão de
  trânsito**; sobre a linha, o **pórtico ferroviário**, montado nos dois trilhos
  de aço que `GroundBaker` pinta para ele — `RailCargoPolicy.MAX_RAKE` define a
  bitola do pórtico e o desvio de manobra, então nenhum dos dois pode discordar
  do outro. A placa **RAMAL 1** fica *na plataforma*, no extremo oeste, que é o
  lado de onde o trem chega; antes ela flutuava quarenta pixels ao norte da
  linha, no meio do pátio, presa em nada.
- **E a estação não anda.** `rail_y()` é constante. Ela já foi
  `world_bottom() - 26` (o ramal inteiro na borda sul, onde ninguém panorâmica) e
  depois `yard_bottom() + 44`, que resolveu a visibilidade e criou coisa pior: o
  pátio cresce a cada parcela comprada, então a cabeceira escorregava uma fileira
  de blocos para o sul a cada expansão e a estação que o jogador tinha aprendido
  onde ficava simplesmente estava em outro lugar. Agora o corredor é uma
  **fileira fixa** (`PortLayout.RAIL_ROW`) e o pátio cresce *do outro lado* dele
  — que também é como um terminal de verdade se expande. Num porto novo a
  geometria é idêntica à de antes; a diferença só aparece quando se compra chão.
- **O ramal cresce** — o tronco *Ramal Ferroviário* da árvore de melhorias move
  os botões que este subsistema já lia: intervalo entre serviços, comprimento da
  composição, tempo de rampa, taxa e teto do automático, e o bônus de composição
  completa. `RailCargoPolicy` e `RailYard` guardam a *linha de base* — porque
  essas são as regras do ramal e precisam ser legíveis e testáveis sem um save —
  e `GameState.rail_stat()` aplica por cima o que foi comprado: soma antes de
  multiplicar, sempre, que é a ordem em que as cartas se leem. O comprimento é o
  único botão limitado pelo chão: `RailCargoPolicy.clamp_rake` segura em
  `MAX_RAKE`, e `PortLayout.rail_west_turnout_x` deriva daí, então o desvio de
  manobra nunca fica curto demais para o trem que a loja permite montar.
- **A composição** — locomotiva com farol que lidera a marcha, fumaça de escape
  medida pela velocidade real (a manobra e a marcha movem a locomotiva em eixos
  diferentes, e o penacho responde aos dois), fumaça de freio sob os truques na
  parada, e três tipos de vagão distribuídos por posição — nenhum vagão
  acoplado é igual ao vizinho, e a mesma composição volta igual depois de um
  reload. Buzina de dois tons, guincho de freio onde os freios de fato entram,
  estrondo do engate quando os para-choques se encontram, e a campainha da
  passagem de nível batida no mesmo relógio que pisca as lanternas.
- **Tráfego** — via de serviço de mão dupla separada em duas colunas, faixa de
  rolamento reservada por veículo e distância de seguimento. Um veículo travado
  devolve o serviço em 12 s em vez de segurar a faixa e matar de fome o resto.
- **Notificações** — `NotificationCoordinator` decide o que merece atenção:
  estado rotineiro (fase do berço, chegada) fica só no histórico. Repetições
  dentro de 8 s viram contagem numa faixa só, um toast por vez e no máximo um
  por segundo, prioridade fura fila. Não há mais etiqueta de berço sobre o
  porto: ela repetia o que o navio e os guindastes já mostravam e cobrava uma
  faixa de tela de celular por isso. O estado continua existindo em
  `Hud.berth_text()`/`berth_progress()` para a árvore de acessibilidade e os
  testes; ninguém o desenha.
- **Acessibilidade** — foco alcança tudo por Tab/setas, Enter ativa, Escape e
  Back fecham; anel de foco de dois tons; nomes acessíveis em toda tecla de
  ícone. Todo texto funcional passa de 4,5:1, verificado por teste.
- **Rotas são uma decisão** — cada escala é **reservada numa rota**, e a rota
  decide três coisas que puxam em direções opostas: quanto a escala paga
  (`reward`), quanto o berço fica vazio depois (`interval`) e que casco chega
  (`classes`). Antes o frete era o **máximo** entre as rotas compradas, então
  comprar rota só podia ajudar, as antigas deixavam de existir no instante em que
  uma mais longa entrava, e o mapa era uma lista de compras com uma linha útil.
  A ordem permanente `RoutePolicy` escolhe: MISTURA reveza tudo, MAIOR FRETE
  pega sempre a que paga mais — cascos maiores, menos escalas, cais parado mais
  tempo — e MAIS ESCALAS pega sempre a que volta antes. Mesma forma da alocação
  de gangue, um passo mais pra fora. Há teste que falha se as duas apontarem
  para a mesma rota, e outro que compara o bônus de partida de uma cabotagem
  contra o de uma travessia **no mesmo porto**.
- **Carta de rotas** — o mundo é um sprite gerado
  (`tools/sprites/gen_worldmap.py`, 96×48) e a carta o desenha em múltiplo
  inteiro: nada é reamostrado. Antes eram doze polígonos preenchidos em tempo de
  execução, escalados para a altura que o painel tivesse — polígono pequeno não
  vira pixel art, vira pixel art borrada. A costa é escrita como vãos de coluna
  por faixa de latitude, então cada trecho confere contra uma coordenada real
  (`col = (lon+180)/3.75`, `lin = (90-lat)/3.75`). Os alfinetes usam a mesma
  projeção, e há teste que amostra o PNG e falha se um deles cair no mar aberto —
  metade deles caía: o Caribe ficava na costa do Equador e a travessia atlântica,
  na Argélia.
- **Frota** — três silhuetas e quatro pinturas de casco, sorteadas de forma
  determinística e sem repetir três vezes seguidas. Todas usam o mesmo
  `ship_top.png` de 66x232 e as mesmas 24 posições; Feeder/Panamax/New Panamax
  são escala, offset e pintura do casco único, como no `origin/main`.
- **Portão** — uma via sai do topo do mapa pra cidade, atravessa a cerca do
  perímetro na guarita e alimenta três vagas na praça. O caminhão **dirige**:
  entra pela faixa sul, contorna as vagas pela aproximação, encosta de nariz
  pro portão, é trabalhado com toque como o navio, e sai pela faixa de saída e
  pela pista norte. Carga nunca aparece na vaga — chega e sai em cima de uma
  carreta, que leva no máximo `GateDock.TRUCK_CAPACITY` caixas porque uma
  carreta de rua leva um contêiner de 40 pés ou dois de 20. Todo caminhão cruza
  o portão carregado. `RoadCargoPolicy` tem três faixas: abaixo da meta a viagem
  é positiva (2 entram, 1 sai), entre a meta e `DRAIN_FILL` é neutra (1 por 1) e
  **acima de 94% ela drena** (1 entra, 2 saem). A terceira existe porque "nunca
  negativa" era um deadlock: pátio de importação cheio recusa pouso, pouso
  recusado trava a descarga, e uma estrada que só troca 1 por 1 nunca abre a vaga
  que destravaria. Drenar é seguro porque o piso é cobrado na coleta:
  `road_pickup_slot` recusa levar abaixo das 24 caixas da próxima escala.
- **Automação** — portêiner, transtêiner e flutuante movem carga sozinhos no
  berço, pela mesma transação do toque. Uma escala inteira acontece sem um
  toque quando há equipamento; o toque vira empurrão. A partida paga um bônus
  medido em segundos da renda atual.
- **O toque sempre leva a algum lugar** — se o berço fica sem jogada legal e sem
  nada no ar por `EXPORT_STARVE_GRACE` (18 s), ele quebra a própria regra e
  reembarca a carga que acabou de desembarcar, avisando por quê. A regra — um
  casco não recarrega o que acabou de largar — continua valendo; o que ela não
  pode é congelar o porto num pátio pequeno que só tem a importação desta escala.
  `tests/cargo_test_runner.gd` monta exatamente esse pátio e falha se o berço não
  se libertar em um minuto.
- **Teto de transferências no ar** — `BerthCallController.MAX_IN_FLIGHT` (6).
  Sem ele todo toque abria outra transferência e o pátio se esvaziava em rajadas
  sem motivo visível, com carga reservada e máquina tomada para um casco que já
  tinha o suficiente a caminho.
- **Nada segura o berço** — a caixa espera o cavalo mecânico por
  `CargoRelay.APPROACH_GRACE` (1,6 s) e não mais. Antes ela parava no cais até o
  prazo da viagem inteira: como o berço conta a transferência em voo até ela
  pousar, um cavalo lento congelava o navio e o toque parava de responder. Há
  ainda um cão de guarda por itinerário — nenhuma apresentação segura uma
  transação além do que ela mesma orçou mais `ITINERARY_SLACK`.
- **Cadeia de custódia** — `CargoRelay` é o itinerário de uma caixa: o portêiner
  tira do costado e põe no apron, o cavalo mecânico dirige até a faixa do bloco,
  o transtêiner levanta da carreta e empilha. A carreta é reservada quando o
  itinerário é desenhado, então o número de caixas sendo dirigidas é exatamente o
  número de máquinas livres — sem carreta livre, a caixa atravessa no arco antigo
  e o toque continua imediato. Qualquer falha (máquina liberada no meio, carreta
  travada, pouso forçado pela captura) desemboca nesse mesmo arco: a apresentação
  pode falhar, a transação não.
- **A frota tem endereço** — o cavalo mecânico é máquina de pátio, sem placa de
  rua: estaciona numa vaga numerada no apron e fica visível entre viagens. Reach
  stacker e empilhadeira são rodoviários e entram pelo portão quando têm serviço.
  Comprar uma máquina sempre tem corpo — ela sacode nas molas e solta um
  `+X TEU/s` sobre si mesma, mesmo quando o teto visual já foi atingido.
- **Perfis** — três terminais independentes em `user://profiles/<n>/`. O slot
  é parte do caminho, nunca do payload, então um save exportado de um entra em
  qualquer outro. O `user://save.json` da build antiga vira o perfil 1 sozinho.
- **Save** — envelope JSON v2 por perfil, escrita temporária,
  rotação de backup, recuperação, migração da versão-base e autosave a cada
  30s. O quadro de retorno presta contas: quanto tempo fora, quanto foi contado,
  a que taxa e a que porcentagem, e quanto o teto recusou — e Ajustes anuncia o
  teto **antes** de o jogador sair. Tocar na etiqueta da taxa abre de onde ela
  vem: máquinas, marcos, melhorias, capital, neblina e surto, cujos fatores
  multiplicam de volta no número do contador. Um cartão que o caixa ainda não
  alcança diz **faltam ~2 min** em vez de só ficar apagado. Progresso offline parte de cap de 8h e 50%
  de eficiência
  (`GameState.OFFLINE_CAP_SECONDS_BASE` e `OFFLINE_EFFICIENCY_BASE`); o ramo
  Offline da árvore de capital sobe isso até 16h e 75%, e todo nó da árvore tem
  que bater o padrão — existe teste que falha se um deles não bater.

## Arquitetura AI-first

O repositório possui um guia operacional em [`AGENTS.md`](AGENTS.md), um hub em
[`docs/README.md`](docs/README.md), documentação por domínio dentro de
`scripts/*/README.md` e um
[mapa gerado de todo o código](docs/reference/code-map.md). Assim, uma pessoa ou
agente começa pelo contrato relevante em vez de vasculhar 17 mil linhas.

```bash
# Atualiza/valida o mapa e roda todas as suítes
tools/qa/run_all.sh
```

As decisões seguem a separação recomendada pelo Godot: cenas/nodes apresentam e
orquestram; classes puras decidem regras; autoloads ficam restritos ao estado
que realmente atravessa cenas.

## Debug

Em build de debug:

- `F2` — screenshot em `user://shot.png`
- `F3` — dinheiro de teste: uma hora da produção atual, ou 1M, o que for maior.
  **Shift+F3** dá mil vezes isso. Escala com o porto, então continua servindo
  depois da primeira hora
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

## Plano de evolução — refeito em 04/08/2026

Este é o documento vivo de produção do HarborClick, e ele foi **zerado**. O plano
antigo descrevia dezoito fases já entregues e não dizia mais o que falta; a
lista abaixo saiu de uma auditoria contra a pesquisa de gênero resumida em
[`docs/design/principios.md`](docs/design/principios.md), com o simulador de
balanceamento executado e a economia lida linha a linha.

**A convenção mudou.** Nada de `[x]`: um item resolvido é **apagado deste
arquivo** no mesmo commit da implementação. O que sobra aqui é, sempre, o que
falta. O histórico de quem fez o quê fica no git, que é onde ele deve estar.

Os itens estão em ordem de execução. Defeito vem antes de feature, e a
instrumentação vem antes do balanceamento, porque sem ela qualquer afirmação
sobre a curva é chute.

---

### 1. Religar os ramos Rotas e Eventos da árvore de capital

Ao consertar os nós mortos do ramo Offline apareceram mais quatro: os ramos
Rotas e Eventos são desenhados com preço e botão, mas
`GameState.buy_prestige_node` recusa qualquer nó com `requires_feature`. Eram
quatro botões que engoliam o toque sem dizer nada. Por ora eles saíram da tela
(`PrestigeDB.purchasable_branches`), que é o mesmo tratamento que
`ProgressionManager` dá às conquistas com feature gate.

Sair da tela não é resolver: `route_reward_multiplier`, `route_slots`,
`event_reward_multiplier` e `event_duration_multiplier` continuam sem nenhum
leitor no jogo. As rotas existem desde a antiga Fase F; os eventos, não.

- [ ] `RouteDB`/`RouteMap` passam a ler os dois stats de rota, e o ramo volta
      à árvore sem `requires_feature`.
- [ ] O ramo Eventos volta junto com o item 6 (eventos raros).

Aceite: nenhum nó visível na árvore recusa a compra, e todo nó comprado move um
número que o jogador vê.

---

### 2. Fechar os últimos 100 s da cadência de novidade

O simulador modela a economia que se joga e agora **duas das três metas
reprovadas fecharam**:

```bash
godot --headless --path . -s res://tools/balance/run_balance.gd -- all
```

| Momento | Meta | Medido |
|---|---|---|
| 0–10 s | primeiro toque recompensado | 0,25 s ✅ |
| até 30 s | primeira renda passiva | 5–15 s ✅ |
| até 60 s | primeira escolha real | 5–15 s ✅ |
| até 5 min | três desbloqueios visualmente diferentes | **6 min 40 s** ⚠️ (era 7 min 25) |
| 60–120 min ativos | primeiro prestígio | 72 min ✅ |
| primeiro dia casual | primeiro prestígio | 17 h 30 ✅ |
| após prestígio | recuperar o pico 3–5× mais rápido | 3,6× ✅ (era 6,1×) |

O que fechou e como: o payback do estivador caiu de 120 s para 85 e o da
empilhadeira de 110 para 80 — **o preço não**, porque neste catálogo o CPS é
derivado do custo e baratear a máquina a enfraquece na mesma proporção. E o
desconto de reconstrução saiu de 75% para 60%, o que devolveu conteúdo ao
segundo run.

- [ ] Os 100 s que faltam. O terceiro tipo é o cavalo mecânico a 1100 TEU, e o
      degrau de 100 → 1100 é o que sobrou. Mexer nele sem derrubar a vazão total
      exige repensar a escada inteira, não uma linha.

Ambas as metas agora têm teste: `tests/phase3_economy_test_runner.gd` falha se a
janela do prestígio ou a razão de recuperação saírem da faixa.

---

### 3. O que o playtest de 05/08/2026 deixou aberto

- [ ] **Fluxo de carga ainda emperra.** A trava de 22 s foi resolvida, mas a
      caixa continua parecendo lenta quando uma máquina a pega. Medir o tempo de
      ponta a ponta por perna e cortar o que não paga.
- [ ] **Terceira máquina ainda a 6min40.** Ver item 2.
- [ ] **A carta de rotas ainda mostra só duas linhas.** O mundo e a mecânica
      foram refeitos; a lista embaixo continua exibindo apenas a rota atual e a
      próxima, sem dizer o que cada uma paga nem com que cadência. Agora que a
      rota é uma decisão, a lista tem que mostrar as três colunas.
- [ ] **Confirmar qual card sai.** Não existe toast de chegada de navio no
      código. Quem anuncia navio é o aviso de berço liberado — agora rebaixado a
      rotina, sem toast — e o modal de escala especial. Se o incômodo é o modal,
      ele vira aviso no sino.
- [ ] **Estrelas/prestígio.** As ações douradas saíram da barra de cima. Falta
      decidir o que elas compram para o reset abrir algo de verdade.

O ramal saiu desta lista duas vezes. Primeiro por dentro: ele tinha um
subsistema inteiro — comprimento da
composição, intervalo entre serviços, tempo de rampa, taxa do automático, bônus
de composição completa — e a loja vendia dois `×2` anônimos para ele. Agora o
tronco **Ramal Ferroviário** tem oito nós e cada um move um botão que
`RailYard`/`RailCargoPolicy` leem de verdade: Sinalização CTC aperta o
intervalo, Composição Dupla alonga a composição, Pátio de Manobras compra tempo
na rampa, Pórtico Ferroviário sobe a taxa **e o teto** do automático, Ramal
Alimentado é sinergia com o armazém, Trem Pesado × Shuttle de Cintura é o par
exclusivo, e Terminal Interior transforma o ramal em porto seco.

O comprimento tem um limite que não é de gosto: `RailCargoPolicy.MAX_RAKE` é 8
porque o desvio de manobra precisa segurar a locomotiva livre da cauda da maior
composição possível, e `PortLayout.rail_west_turnout_x` passou a ser *derivado*
desse número em vez de sete pitches escritos à mão — do jeito antigo, o primeiro
upgrade que alongasse o trem deixaria a locomotiva engatando a oeste do próprio
desvio, em cima do lastro. Por isso o par exclusivo do ramal negocia no relógio
(rampa × intervalo) e não no comprimento.

Depois por fora, no playtest de 21/08/2026, que achou três coisas que nenhum
teste pegaria porque nenhuma delas é sobre regra:

- **A estação andava.** `rail_y()` derivava de `yard_bottom()`, que cresce a
  cada parcela — a cabeceira escorregava para o sul a cada expansão. Agora é
  fileira fixa e o pátio cresce do outro lado. Ver *Sistemas*.
- **Os contêineres vinham atravessados.** O vagão é desenhado de nariz pra cima
  e leva um quarto de volta para apontar para leste; a caixa é desenhada deitada
  (24×13) e já apontava certo. Levava o quarto de volta junto, o que punha um
  contêiner de quarenta pés atravessado num vagão mais estreito que uma pessoa.
- **A placa estava perdida.** Ficava quarenta pixels ao norte da linha, no meio
  do pátio, por cima dos vagões. Agora fica na plataforma, e existe plataforma
  para ela ficar em cima.

---

### 4. Comprar não é uma decisão

A prateleira virou árvore. `upgrade_db.gd` deixou de ser dezoito cartas `×2` e
passou a ser um grafo: cada nó diz o que o abre (`requires`), alguns se recusam
a conviver com o vizinho (`excludes`), e três tipos novos existem — `synergy`
(uma máquina rende em função de *outra*), `transform` (a máquina passa a fazer
outra coisa) e `rail_stat` (mexe num botão de verdade do ramal, ver item 3).

O que fechou:

- **Sinergia.** Bloco Alimentado, Atracação Limpa, Ramal Alimentado e Fila
  Única pagam por unidade de uma máquina *diferente*. Um porto com quinze RTGs
  e dois cavalos mecânicos agora tem motivo para ir comprar cavalos.
- **Exclusão mútua.** Estoque Profundo × Giro Rápido no pátio, Escala Profunda ×
  Cadência de Cais no berço, Trem Pesado × Shuttle de Cintura no ramal — cada
  par é "profundidade × cadência" numa camada. A troca custa `SWAP_SURCHARGE`
  (3×) e o perdedor sai na mesma transação: cara, como pedido, mas possível.
- **Transformacional.** Cinco nós `group: "conductor"` — Turma de Terra, Bloco
  Mestre, Cais Dedicado, Terminal Interior, Centro de Controle. A máquina para
  de produzir e passa a pagar uma fração ao porto inteiro por unidade dela
  mesma. Só um pode estar montado: é a resposta a "quem manda neste terminal".
- **O escopo `structures` morreu e o nó virou outra coisa.**
  `throughput_structural` era `add_pct` no mesmo produto que `global` — dois
  nomes e dois preços para um número só. Agora paga por *tipo* de máquina que o
  terminal opera de verdade (`EconomyMath.BREADTH_MIN_COUNT` unidades), que é
  uma forma que o nó global não consegue imitar: premia porto largo, não porto
  grande.
- **A curva parou de ter penhasco.** Sinergia e condutor pagam por
  `EconomyMath.saturating_bonus`, que começa na taxa que a carta promete e
  dobra em direção ao teto sem nunca chegar. Um teto duro fazia a centésima
  unidade valer 1,5% e a centésima-e-primeira valer zero — a build morria no
  instante em que dava certo.
- **A loja mostra a árvore inteira.** A aba de melhorias é construída uma vez e
  nunca reconstruída (uma lista que se refaz num timer come o toque e joga fora
  a rolagem de quem estava lendo três nós à frente). Todo nó do catálogo está
  lá desde o primeiro minuto, indentado por profundidade, e um nó fechado diz
  em uma linha o que o abre: *"Abre com: Café de Rancho"* ou *"Faltam 12 x
  Estivador"*.

O simulador acompanha: `EconomySimulator` reproduz os três tipos novos, respeita
`requires`/`excludes`, e ganhou dois cenários — `build_wide` e `build_tall` —
idênticos em tudo menos na metade da árvore a que se comprometem.

- [ ] **O que o simulador ainda *não* prova: composição de frota.** Em 3 h,
      `build_wide` termina com 169,9 M TEU/s e `build_tall` com 232,2 M — 1,37×,
      bem dentro do que errar custa —, cada uma regida por uma identidade
      diferente (condutor 2,55 contra 3,52) e com conjuntos de nós diferentes.
      Mas a *forma* das frotas quase não muda: `composition_distance` dá 0,006,
      ou seja, as duas montam praticamente a mesma pirâmide. Isso não é um nó
      fraco: com uma única curva
      `1.15^n` compartilhada, um multiplicador `×M` numa máquina desloca a
      contagem de equilíbrio dela em apenas `ln(M)/ln(1.15)` unidades — sete
      unidades para um `×3`, contra frotas de cem. Enquanto todas as máquinas
      dividirem a mesma curva de custo, nenhum multiplicador realista muda a
      pirâmide. Fechar isso pede mexer na *curva*, não no catálogo: taxas de
      crescimento por máquina, ou vagas/limites de frota por tipo. É uma
      rebalanceada do jogo inteiro e por isso está aqui e não foi feita junto.

Hoje o cenário `wrong_buy` — o agente que sempre compra a pior opção — termina
2,4× atrás do guloso na mesma configuração. Errar custa 2,4× e não condena a
run, que era o critério; `build_wide` e `build_tall` ficam bem dentro disso, que
é o teste que `test_builds_diverge_and_both_stay_viable` fixa.

Aceite (parcial): dois jogadores com o mesmo tempo de jogo têm portos fortes por
razões diferentes e defensáveis. Falta a frota *parecer* diferente.

---

### 5. Comparar a run anterior com a nova depois do reset

O diálogo já responde o que se perde, quanto se ganha e **em quanto tempo o pico
volta** — `GameState.estimate_rebuild_seconds` roda o simulador a partir do
estado pós-reset e devolve segundos de verdade, não um chute. Falta o outro lado
da regra 7: depois de confirmar, mostrar a run anterior contra a nova para o
ganho ficar visível em vez de prometido.

- [ ] "Run anterior: 80 min até aqui. Esta: 13 min." depois da reconstrução.
- [ ] O `last_run_summary` já é persistido e ninguém o lê.

---

### 6. O horizonte de dias e semanas está vazio

Uma só camada de prestígio, sem meta-prestígio. Nenhum evento raro. Sem coleção
de bandeiras ou pinturas de casco. Sem temporada. A tabela de horizontes da
pesquisa para em "horas" neste jogo.

- [ ] **Eventos raros** (a antiga Fase G): scheduler determinístico com
      cooldown, pity e seed; Golden Ship; OVNI sobre proxy visual; baleia,
      tempestade, regata e inspeção aduaneira. Nada que bloqueie o berço,
      corrompa carga ou puna offline.
- [ ] Coleção de pinturas de casco e bandeiras ligada a rotas e conquistas.
- [ ] ETA e mix de carga por rota; integrar ETA ao progresso offline.
- [ ] Meta-prestígio: uma segunda camada que reinterprete a primeira.

---

### 7. Renumerado — o gato e o `fmt()` fecharam

Os dois itens que ocupavam este lugar saíram do plano, que é o que esta lista
faz com item resolvido.

**O gato** multiplicava só o `click_power`, então o achado mais raro do jogo
virava pó no dia em que a automação chegava. Agora ele concede **surto global**
via `grant_surge` — o mesmo caminho das escalas especiais, que multiplica tudo
que o porto ganha, toque incluído. Caiu de ×7 para ×3 justamente porque deixou
de valer só para o clique, e fica abaixo de qualquer recompensa de escala (×2 a
×10), que são *ganhas* num minigame enquanto o gato é *encontrado*. `grant_surge`
mantém o mais forte, então um gato que passeia durante um surto de ×10 estende o
prazo em vez de rebaixar o prêmio.

**O `fmt()`** tinha dois defeitos. O ponto decimal era anglófono: "1.2B" num
jogo pt-BR é um número diferente do que o jogador lê, e o contador é a string
mais lida do jogo. A marca decimal agora é dado localizado (`number.decimal`),
em cache e reatada em `Loc.language_changed` — não é uma consulta de tabela por
quadro. E a escala tinha fim: o laço parava de dividir ao acabar a tabela de
sufixos, então um porto acima de 10³⁶ imprimia `10000000Dc`, um número que
cresce no dígito alegando estar na maior unidade que existe. Passou a cair em
expoente (`1,0e36`), que fica em três algarismos significativos para sempre e
cabe no visor recortado para `8,88Qa`.

Duas armadilhas ficaram documentadas em teste, porque as duas passariam num
review: o operador `%` do Godot **não tem `%e`** (pedir um levanta "unsupported
format character" exatamente em 10³⁶, o caso que o ramo existe para tratar), e
`log(1000)/log(10)` vale 2,9999999999999996 — o `floor` cai uma década e a
mantissa sai como 10, imprimindo `10,0e35` para 10³⁶. A mantissa é arredondada
para o dígito que vai ser *impresso* antes de normalizar, senão 9,99 vira "10.0"
e a string mente dez vezes o próprio expoente.

---

### 9. Terminar a tradução do conteúdo

A casca do jogo está nos nove idiomas: título, console, relógio, contador,
loja (abas, ordens permanentes, ramal, capataz, decoração), mapa de rotas e
ajustes. O conteúdo dos catálogos ainda não está, e num aparelho em qualquer um
dos outros oito idiomas ele aparece em português no meio de uma tela
traduzida — que é pior do que uma tela inteira em português.

**A casca ficou inteira.** O tutorial do Seu Waldemar, o tour de destaques, o
quadro offline e as dicas de passo saíram do código e viraram chave — a voz dele
foi mantida nas nove traduções em vez de virar instrução, porque o tom é parte da
integração. `core_test_runner` passou a medir o quadro offline em **todos** os
idiomas contra `OfflinePopup.MAX_LINE`, e não só no que a suíte roda: o quadro
não quebra linha, então tradução longa é frase cortada num aparelho que ninguém
testando em português abriria. O teste de i18n pegou dois travessões russos que a
fonte bitmap não tem — exatamente o defeito que ele existe para pegar.

Falta o conteúdo dos catálogos:

- [ ] `structure_db` e `upgrade_db`: nome, piada e efeito de cada máquina. A
      árvore de melhorias (item 4) **aumentou esta dívida de propósito**: são
      ~54 nós em vez de 18, cada um com nome, descrição e agora um rótulo curto
      de mapa, tudo só em português. As frases de estado — *"Abre com: {name}"*,
      *"Faltam {count} x {name}"*, *"Troca {name}"* — já estão nos nove idiomas;
      o que elas interpolam, não. Numa tela em turco lê-se hoje
      "Şununla açılır: Café de Rancho".
- [ ] `port_journal`, `npc_card` e os dois minigames: as abas, os doze ramos do
      quadro de honra e as linhas de tarefa da equipe continuam fixas no código.
- [ ] `achievement_db`, `contract_db`, `task_board` e `npc_catalog`.
- [ ] `land_db`, `cosmetic_db`, `prestige_db`, `special_call_db`,
      `ship_catalog`.
- [ ] Marcos de `game_state.gd`, avisos de `save_manager.gd`, tutorial,
      diário, prestígio, popup offline e os dois minigames.
- [ ] Um teste que falhe quando um catálogo ganhar texto sem chave, para o
      conjunto não voltar a divergir sozinho.

---

### 10. Fechamento de plataforma

- [ ] Medir 60 FPS num aparelho móvel real.
- [ ] Testar pause/background/resume em Android e iOS.
- [ ] Rodar a build web e confirmar persistência de `user://` no navegador.
- [ ] Página web/PWA.

---

### Definition of Done de qualquer feature

Uma feature só pode ser considerada concluída — e o item apagado daqui — quando:

1. regra e estado persistido têm uma fonte de verdade;
2. caminho feliz, limites e reload possuem teste;
3. touch, mouse e teclado não disparam ações involuntárias;
4. telas afetadas passam pela matriz responsiva;
5. feedback visual/sonoro tem hierarquia e opção de reduzir movimento;
6. performance foi medida no cenário de estresse relevante;
7. save antigo migra ou recebe fallback explícito;
8. texto, números e contraste continuam legíveis;
9. documentação é atualizada no mesmo commit.

Os três primeiros itens do checklist de aceite de `principios.md` continuam
valendo por cima deste: **vê-se? lê-se? decide-se?**
