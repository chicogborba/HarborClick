# HarborClick

Clicker/idle de terminal de contêineres. Mobile, retrato, pixel art top-down.
Godot 4.7 · todos os assets (sprites, fonte, SFX e música) são **gerados por
código**.

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
  ui/          ui_theme, port_icon, readout, command_rail, hud, shop,
               shop_card, tutorial, Diário, capital, notification_coordinator,
               notice_bell, npc_card, settings_panel, offline_popup
tools/
  venv/        Python + Pillow
  sprites/     geradores de pixel art, fonte e UI
  audio/       synth chiptune + geradores de SFX/música
  capture/     harness de screenshot (roda o jogo de verdade em toda a matriz
               de resolução e falha se algum overlay sair do viewport) e
               medição de frame time no cenário de estresse
  docs/        gerador do mapa completo do código
  qa/          documentação fresca + import + todas as suítes em um comando
  export/      build web reproduzível + servidor local com COOP/COEP
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
  o portão carregado. `RoadCargoPolicy` só autoriza viagens positivas (2 entram,
  1 sai) ou neutras (1 entra, 1 sai), e a coleta para antes de consumir as 24
  caixas da próxima escala.
- **Automação** — portêiner, transtêiner e flutuante movem carga sozinhos no
  berço, pela mesma transação do toque. Uma escala inteira acontece sem um
  toque quando há equipamento; o toque vira empurrão. A partida paga um bônus
  medido em segundos da renda atual.
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
  30s. Progresso offline tem cap de 8h e 50% de eficiência.

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

#### O pórtico de sinalização — revisado em 30/07/2026

O contador sem placa resolveu o problema errado. Tirar o painel tirou o ruído,
mas também tirou o objeto: sobraram um número contornado, uma taxa contornada,
um chip de ardósia e uma caixa de madeira com relógio dentro, quatro coisas
soltas boiando num degradê. Nada dizia que fossem a mesma interface, e nenhuma
delas parecia pertencer a um terminal.

A interface passa a ter **dois materiais, e o material diz o que a coisa é**:

- **aço esmaltado** é o terminal falando de si mesmo — o pórtico parafusado no
  topo do porto com os instrumentos embutidos, o console das teclas embaixo e o
  vidro escuro atrás do número. Azul-marinho, risco de escovado fino e um
  filete âmbar na aresta que dá pra água. Tudo que fica **permanentemente**
  sobre o porto é aço, então lê como parte da estrutura e não como painel
  flutuando por cima;
- **papel** continua sendo o papelório: prancheta, prendedor, manifesto,
  fichas. Tudo que **abre** é papel, então lê como algo entregue na mão.

O que isso muda, item a item:

- o contador virou totalizador de balança: dígitos âmbar acesos atrás de vidro,
  numa janela de largura fixa cortada para o maior número que `GameState.fmt`
  produz (`8.88Qa`), com os dígitos **alinhados à direita** dentro dela. A
  origem continua invariável — agora por reserva, não por alinhamento — e a
  taxa ao lado nunca é empurrada;
- as casas que o número ainda não alcançou não ficam vazias: carregam **oitos
  apagados**, como o segmento que o mostrador não está acionando. A fonte é
  monoespaçada, então o trecho apagado e o número aceso encaixam célula a
  célula sem sobrepor um pixel — e a largura reservada vira leitura de
  progresso em vez de buraco;
- ganhar TEU **acende o vidro** por 0,22 s. É o "isso pagou" mais barato
  possível: nada de geometria se mexe, então pode disparar a cada caixa
  creditada sem a barra tremer. Respeita `UserPreferences.can_animate()`;
- o estado do berço saiu do chip de ardósia e virou uma **ficha esmaltada
  pendurada** no pórtico, com lâmpada de status (âmbar piscando quando o toque
  paga, teal quando é só automação) e um fio de barra de progresso. O retrato
  não tinha progresso nenhum: o card do berço só existe no rail, que só existe
  em tela larga;
- o relógio perdeu a caixa de madeira e virou uma **vigia de latão** encaixada
  na ponta direita do mesmo pórtico. `Hud.BAR_H` é o contrato entre os dois. O
  vento deixou de ocupar onze caracteres em palavra e virou três pips;
- em retrato as teclas viraram **console**: quatro teclas de peso igual, glifo
  de 24 px sobre a palavra, e AJUSTES finalmente com nome em vez de um quadrado
  de 40 px. A LOJA acende um ponto âmbar quando existe algo comprável agora —
  metade do laço de um clicker é gastar, e essa metade era invisível até abrir
  a loja e conferir;
- o pórtico acompanha o **mundo**, não a janela, então em tela larga ele para
  onde o rail começa. Com ele visível nos dois perfis, o rail devolveu o
  contador: existe **um** número no jogo, não dois para manter em sincronia;
- a câmera passou a conhecer o cromo (`PortCamera.set_view_insets`). Sem isso o
  pórtico sentava em cima do portão e o console em cima da última fileira de
  galpões, e nenhum arrasto trazia os dois de volta — a câmera parava na borda
  do terminal, não na borda do que dá pra ver;
- o navio atraca 36 px mais abaixo (`PortLayout.SHIP_Y` 60 → 96): a proa ficava
  na faixa do pórtico e da via de acesso, ou seja, meio casco era cromo e meio
  era fora de quadro exatamente na hora de tocar nele.

Aceite: `ui_p0_test_runner` continua provando que ícone, origem do número e a
linha de taxa não se movem de 0 a `1e15`; `contrast_test_runner` cobre as oito
combinações novas de tinta sobre aço; e `tools/capture/capture.tscn -- matrix
world` falha se o contador ou o relógio saírem do pórtico, se a ficha do berço
subir por baixo dele ou se ela encostar no console.

#### Aviso, crachá e o que se pode tocar — revisado em 30/07/2026

Quatro coisas que o playtest chamou de "muito ruim mesmo", e as quatro tinham a
mesma raiz: a interface interrompia, ou respondia, quando ninguém pediu.

- **Notificação virou sino.** Cada aviso chegava como faixa sobre o cais,
  entrava, ficava três segundos e saía — sempre em cima da parte da tela que o
  jogador estava olhando, pra dizer algo que ele acabou de ver acontecer. Agora
  nada interrompe: o aviso acende uma lâmpada no sino na ponta do pórtico e
  espera ser lido. `NotificationCoordinator` continua decidindo o que vale
  guardar e continua colapsando repetição — só deixou de existir quem parasse o
  jogo pra contar. `ToastLayer` saiu; `NoticeBell` entrou, e ele responde
  `notify_shown_finished()` na hora, senão a fila trava esperando uma faixa que
  não existe mais.
- **Tooltip.** Era o único pedaço de interface que o jogo não desenhava: caixa
  cinza arredondada na fonte padrão da engine, sobre um porto em pixel art. Um
  tooltip é um popup pendurado na `Window`, não no controle que o pediu, então
  `UiTheme.install_window_theme()` é o único lugar que alcança ele.
- **Tocar em máquina não abre ficha de gente.** A inspeção usava `is_crew()`,
  que é verdade pra qualquer coisa com operador — ou seja, todo reach stacker,
  transtêiner, portêiner, rebocador e carreta do portão era uma ficha esperando
  pra abrir. Agora é `is_person()`: só quem está no pátio a pé. Quem trabalha
  dentro de uma cabine continua na aba EQUIPE do Diário, que é a lista do turno
  inteiro.
- **A ficha virou crachá.** Era um formulário sobre uma pessoa: linhas com
  legenda, nome no topo e nenhuma foto em lugar nenhum. Um terminal emite
  crachá pro pessoal dele, então é isso que tocar em alguém entrega — laminado,
  tarja teal com o nome do porto, retrato montado e o registro impresso ao
  lado. O retrato é de `portrait_sheet` (24x28, seis rostos), escolhido pelo uid
  da pessoa, com o capacete como camada cinza separada pro `modulate` tingir —
  mesmo truque do sprite que anda, e pela mesma razão. Despachante e comandante
  de rebocador saem sem capacete: nenhum dos dois usaria um.

#### Dois cascos nunca dividem o canal — 30/07/2026

Com vários navios atracados, o que manobrava atravessava os outros. A ideia
original era "passa por fora" — `FAIRWAY_X` a 8 px do berço — e 8 px num casco
de 66 não é passar por fora, é passar por dentro com a borda aparecendo.

**Não tem offset que resolva.** O mundo tem 320 px, a água tem 80 e o casco tem
66: pra um casco passar limpo por outro atracado ele teria que começar em x 310
e terminar em 376, fora do mapa. Duas embarcações não cabem lado a lado, ponto.

Então nada passa. O casco só anda de proa (o sprite é desenhado apontando pro
norte), logo o canal corre sul → norte, e quem decide se dá pra usar é quem já
está atracado:

- **canal livre** — a manobra completa: sobe pelo fairway, encosta no fim, e sai
  pelo topo. É a cena que o porto foi construído em volta;
- **tem alguém no caminho** — os rebocadores tiram o navio **direto pro mar**, de
  través, saindo pela borda leste do quadro. Que é como se tira um navio do cais
  de qualquer jeito: primeiro afasta da parede, depois é que se navega.

`PortWorld.lane_clear_north/south` decide, `PortLayout.OFFING_X` é onde a rota
lateral termina. E como o afastamento lateral é feito com y constante, e os
berços são espaçados 258 px pra cascos de no máximo 232, essa rota **não pode**
cruzar ninguém — é geometria, não é sorte.

Dois efeitos colaterais que valem por si:

- sair do cais virou uma perna própria da manobra em vez de acontecer junto com
  a corrida pro norte. Um casco que dispara pro norte no instante em que soltam
  as amarras lê como se estivesse deslizando pela parede em que estava amarrado;
- a esteira agora depende de **estar navegando**, não da fase. Navio sendo
  rebocado de través a passo de homem não faz esteira.

Aceite: `phase4_ship_test_runner` prova a premissa geométrica (se alguém alargar
o mundo, o teste avisa que a regra pode ser afrouxada), a tabela de bloqueio nas
três configurações de cais, e que as duas rotas estão ligadas à resposta. O shot
`unberth` do harness mostra o berço do meio saindo com os dois vizinhos
atracados, e falha se o casco não sair da parede.

#### Pegar o pessoal no colo — 30/07/2026

Tocar num boneco abre o crachá. **Segurar** levanta ele do chão: cresce (está
mais perto da câmera do que o pátio), balança preso pela nuca, chuta, e a
sombra fica onde ele estava — mais aberta e mais fraca, que é a única coisa na
tela dizendo a que altura ele está. Solta e ele cai, amassa no pouso, e volta a
andar. É o Mii Plaza do porto, e é a única coisa no jogo que se faz com uma
pessoa em vez de com carga.

Custa zero pra simulação: a ronda que ele estava fazendo é uma tarefa presa no
quadro e continua presa enquanto ele está no ar, então ser carregado do outro
lado do terminal só significa que a volta a pé é mais longa.

Três decisões que o teste protege:

- toque e segurar dividem o mesmo aperto, e nunca disparam os dois — `GRAB_HOLD`
  (0,26 s) decide, e `GRAB_SLOP` (10 px de percurso) entrega o aperto pra câmera;
- máquina com operador continua sendo máquina: só `is_person()` sobe do chão;
- ninguém é largado na água — a soltura prende a posição ao terminal.

O navio mantém luzes de navegação e seis holofotes de convés, mas a camada
posterior de cabines foi removida junto com a frota de PNGs por classe. As luzes
agora usam diretamente as coordenadas do casco único do GitHub.

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

Um save novo nasce com 24 caixas rastreáveis do comboio rodoviário inaugural,
todas com UID próprio e origem `cidade`, já entregues no setor de exportação
antes do primeiro turno. Portanto, a primeira cena já tem contêineres, o
primeiro navio consegue descarregar, carregar completamente e partir sem um
tutorial artificial. Saves de pátio v2 drenados pela regra antiga recebem uma
única correção rastreável antes de a cena aparecer; depois de persistidos em v3,
restaurar um pátio vazio e o loop normal nunca repõem caixas do nada.

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
  com perfis retrato/paisagem; 18 suítes headless; harness de captura que roda
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
- **Interface** — dois materiais: aço esmaltado para o que fica sobre o porto
  (pórtico, console, vidro do contador) e a prancheta do conferente para o que
  abre. Nine-patches na grade de pixel, loja reconstruída, notificações com
  política única.
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

### Diagnóstico do playtest — 30/07/2026, segunda passagem

Os três sintomas relatados depois da entrega das fases A–E, e o que estava por
trás de cada um. As regras de gênero que eles violam estão em
[`docs/design/principios.md`](docs/design/principios.md).

| Sintoma relatado | Causa | Fase |
|---|---|---|
| "Compro coisas mas parece que nada acontece" | Cavalo mecânico, reach stacker e empilhadeira ficavam **invisíveis** fora do mapa entre viagens, e o teto visual de cada máquina era 1 ou 2. Comprar a décima não mudava um pixel, e a taxa nova aparecia num contador atrás da loja aberta | P |
| "Não sei se a compra valeu a pena" | O cartão dizia preço e produção, nunca **quanto tempo leva pra se pagar**. Sem denominador comum, duas máquinas de preços muito diferentes não eram comparáveis | P |
| "Falta um fluxo claro do contêiner; as máquinas deviam interagir entre si" | A caixa voava do porão direto pro bloco. O portêiner animava por cima do voo, o transtêiner rodava um ciclo decorativo sobre um bloco qualquer, e os cavalos mecânicos faziam recados de portão que não tocavam a carga do navio. Nenhuma máquina passava carga pra outra | P |

### Fase P — a cadeia do contêiner e o peso da compra — P0

O contêiner deixa de teleportar e passa a ter **cadeia de custódia**: cada perna
do percurso pertence a uma máquina que o jogador comprou.

```text
NAVIO  --portêiner-->  APRON  --cavalo mecânico-->  FAIXA DO BLOCO  --transtêiner-->  PILHA
PILHA  --transtêiner-->  FAIXA  --cavalo mecânico-->  APRON  --portêiner-->  NAVIO
CARRETA DE RUA  --máquina de pneus-->  APROXIMAÇÃO  --carreta-->  FAIXA  --transtêiner-->  PILHA
```

- [x] `CargoRelay` (`scripts/world/cargo_relay.gd`): itinerário de três pernas
      sobre o mesmo contrato do `FlyingContainer`, então a camada de carga não
      mudou uma linha. `duration()` responde antes do primeiro frame, `landed`
      dispara exatamente uma vez, e o nó se libera em seguida.
- [x] **Nada trava.** Toda falha desemboca no arco simples de antes: máquina
      liberada no meio da viagem, carreta travada 22 s, ou pouso forçado pelo
      harness de captura. `tests/relay_test_runner.gd` prova os três, mais uma
      escala inteira ponta a ponta.
- [x] **O toque continua sendo um toque.** A carreta é reservada no momento em
      que o itinerário é desenhado; sem carreta livre não existe relé, e a caixa
      atravessa na velocidade antiga. O número de caixas sendo dirigidas é
      exatamente o número de máquinas livres pra dirigi-las — e é por isso que
      comprar mais uma é visível.
- [x] `PortLayout` ganha o **interchange**: o apron sob o trilho do portêiner
      (que também é a via tronco norte-sul do terminal), a faixa de rolamento na
      ponta marítima de cada bloco, e a aproximação em frente às vagas do
      portão. Uma caixa está sempre ou numa máquina com nome ou num chão que uma
      máquina alcança.
- [x] Portêiner e transtêiner **sombreiam** a caixa em vez de animar num timer:
      o carro segue a posição real do contêiner, e o transtêiner rola pela fileira
      pra encontrá-lo.
- [x] O cavalo mecânico virou o que a própria descrição dele diz que é: máquina
      de pátio sem placa de rua. Não pega mais recado de portão, estaciona numa
      **vaga numerada** no apron e fica visível o tempo todo. Reach stacker e
      empilhadeira continuam rodoviários e entram pelo portão.
- [x] Tetos visuais subiram onde ver mais máquinas é o ponto: 5 cavalos, 3
      portêineres, 3 transtêineres, 2 reach stackers, 2 empilhadeiras.
- [x] Toda compra tem corpo: a máquina sacode nas molas, sai um `+X TEU/s` sobre
      ela no pátio, e a taxa no contador anuncia o ganho em porcentagem. Compras
      acima do teto visual caem sobre uma máquina que já existe.
- [x] O cartão da loja mostra **tempo de retorno** (`paga em 4min`) assim que a
      máquina é acessível. É o único número que torna duas máquinas de preços
      muito diferentes comparáveis.
- [x] Melhoria comprada tem corpo na máquina: um farol âmbar por upgrade
      instalado, em fila curta no nariz e piscando fora de fase. Um reach stacker
      de fábrica e um com três melhorias se distinguem do outro lado do terminal
      sem ler número. São luzes e não arte nova de propósito — os sprites saem de
      `tools/sprites`, e uma marca que não exige regeneração acompanha a tabela
      de upgrades pra onde ela for.
- [x] Captura `relay_hand_off`: o harness espera uma caixa ser **dirigida** ao
      menos 26 px numa carreta antes de fotografar, e falha se em 20 s nenhuma
      chegou a um chassi.

Pendente nesta fase:

- [ ] A máquina de pneus **pegar do leito da carreta**: hoje a caixa dá um salto
      curto do leito até a aproximação e só então sobe no chassi. Falta a lança
      do reach stacker estendendo até o caminhão.
- [ ] Trilhos de pátio: com muitas carretas ao mesmo tempo o corredor do apron
      vira fila indiana sem prioridade. O `TrafficCoordinator` cobre a via de
      rua, não o apron.
- [ ] A carreta ainda não é semirreboque: o cavalo mecânico carrega a caixa em
      cima dele em vez de puxar um chassi articulado.
- [ ] Empilhamento visível: o transtêiner sombreia a caixa até o slot, mas não
      encaixa entre as pilhas vizinhas — passa por cima delas.
- [ ] Inconsistência conhecida: `GateDock.AUTO_MOVERS` ainda conta `tt` na taxa
      de automação do portão, e o cavalo mecânico não trabalha mais carreta de
      rua. Não foi mexido junto porque é número de balanceamento coberto pelas
      suítes `gate` e `phase3_economy` — trocar exige rodar o simulador, não uma
      edição de uma linha.

Aceite: uma escala inteira com equipamento comprado não move uma única caixa
sem uma máquina embaixo dela ou uma máquina que acabou de largá-la; sem
equipamento, o jogo se comporta exatamente como antes.

### Fase A — o console — P0, encerrada em 04/08/2026

Esta fase nasceu pra consertar o desktop: um terço da tela era cinza vazio com
dois botões soltos. Ela entregou o rail — e a Fase Q, que veio depois e é a que
o jogador pediu, travou o jogo em retrato e tornou o rail **inalcançável**.

O rail foi **apagado**, não mantido dormente. Não é limpeza: o board de desktop
era o único lugar do jogo com a tecla `ABRIR CAPITAL`, então o prestígio inteiro
— a árvore de capital, o reset, o pilar "todo reset abre um futuro" — estava
fora de alcance de qualquer jogador. Uma tela que não abre não é código extra
esperando um dia útil; é onde uma feature some sem ninguém notar.

- [x] Em retrato, as teclas são um console de aço no polegar.
- [x] Reservar a largura da barra de rolagem (`SCROLL_MODE_RESERVE`) em vez de
      desenhá-la por cima do conteúdo, e trocar a tábua de madeira chapada por
      calha funda com pega arredondada.
- [x] Corrigir a sobreposição entre a taxa do contador e o chip do berço.
- [x] Barra de progresso do Diário com altura de barra, não de sublinhado.
- [x] Board de desktop, `ObjectiveChip` e o perfil `desktop` do
      `ResponsiveShell` removidos. `ResponsiveShell.PROFILE` virou constante, e
      a suíte `ui_p0` falha se um segundo perfil voltar.
- [x] **O console ganhou cabeça**, porque o que o rail carregava e o telefone
      nunca teve era exatamente o que o jogo precisava mostrar: uma linha que
      responde "e agora?". À esquerda o objetivo com progresso — que estava
      invisível em todo lugar, contra o pilar 3 e contra a meta "próximo
      objetivo sempre visível". À direita **uma** ficha, por prioridade:
      reconstruir o porto, senão comprar, senão `em 4min`.
- [x] `Shop.next_purchase_eta()`: quanto falta pra próxima compra possível,
      medida na renda atual. É a regra 2 de `principios.md` — espera que não dá
      pra dimensionar é stall.
- [x] Lâmpada por berço na ficha do berço. Com três navios atracados o retrato
      só falava de um; os outros dois eram invisíveis até alguém tocar neles.

Aceite: o prestígio é alcançável em retrato; o objetivo e o tempo até a próxima
compra estão visíveis sem abrir nada; nenhuma lista desenha a barra de rolagem
sobre um card.

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

- [x] `PortLayout` ganha berços múltiplos; o segundo e o terceiro são
      destravados por marcos de terreno. Auditado em 30/07/2026: `BERTH_MAX`,
      `berth_count()` derivado da profundidade do mundo e `_ensure_berths()`
      estavam entregues e o checkbox estava desatualizado. A captura `fleet`
      compra as parcelas e fotografa os três cascos alinhados.
- [x] `ShipCatalog` tem três silhuetas e quatro pinturas, com a classe
      sorteada entre as que o terminal já é grande o bastante pra atender.
- [x] Capacidade visual fixa por classe. Feeder, Panamax e New Panamax usam as
      mesmas 24 posições do `ship_top.png`; as pequenas variações de escala e
      pintura são as do catálogo atual no GitHub e não mudam a transferência.
- [x] A classe sorteada depende do tamanho do pátio (`unlock_blocks`): um
      porto de primeira hora só vê feeder, e o primeiro Panamax no berço é um
      evento visível em vez de um número subindo.
- [x] Cada berço tem seu próprio `BerthCallController` e sua própria linha de
      estado. Auditado em 30/07/2026: `PortWorld.berths` e `berth_report()`
      alimentam o rail com uma linha por berço; o checkbox estava desatualizado.
- [ ] `FleetDirector` agenda chegadas, mantém uma fila de espera fora do porto
      quando todos os berços estão ocupados, e persiste a fila. **Parcial:**
      `_drive_arrivals` + `_turnaround` já espaçam chegadas e respeitam o canal
      de uma via, mas isso vive dentro do `PortWorld` e a fila não é persistida.
      Extrair para uma classe própria continua pendente.

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
- [x] Rebocadores comprados acompanham a manobra de atracação e
      desatracação, um em cada alheta; durante a operação aguardam ao largo,
      com rastro de hélice e luzes próprias. O navio mostra amarras de proa e
      popa somente enquanto está de fato no berço.
- [x] Haulers dirigem: aceleram, freiam ao chegar e giram através do arco em
      vez de trocar de rumo num frame. O alvo continua sendo um dos quatro
      lados (os sprites só têm quatro), mas **virar** leva tempo — era a
      virada instantânea que fazia o pátio parecer caixas deslizando.
- [x] Cada viagem tem um alvo legível: o veículo desacelera na pilha, levanta
      poeira ao parar, trabalha, e só então sai.
- [x] Estivadores fazem rondas e param onde chegam, em vez de pendular.

Aceite: gravar 30 s do pátio e nenhum veículo anda de lado, de ré, ou pára no
meio do nada.

### Fase F — mapa-múndi e rotas — P2

- [x] Mapa estilizado com o porto no centro e destinos ao redor: carta com
      costa, grade de coordenadas, alfinete de casa e as linhas das rotas que o
      porto tem, tudo desenhado a partir do mesmo dado.
- [x] Rota comprável com origem, destino, classe de navio e frete; a rota
      decide que casco atraca. **ETA e mix de carga por rota continuam
      abertos** — hoje a rota muda quem chega e quanto paga, não quando.
- [x] Trade-offs: a cabotagem chama sempre e paga a taxa base, a travessia paga
      várias vezes mais. Rota **arriscada com eventos** espera a Fase G.
- [x] Uma rota nova muda o navio e o frete já na escala seguinte.
- [ ] Integrar ETA ao progresso offline.
- [ ] Coleção de pinturas de casco e bandeiras ligada a rotas e conquistas.

Aceite: comprar uma rota muda o mundo dentro de duas escalas; trocar de rota
não perde nem duplica manifesto; o mapa é usável com uma mão.

### Fase I — a tripulação do porto — P1

O playtest disse que as máquinas "parecem mover coisas sem sentido" e que o
pessoal do pátio "parece aleatório, sem cuidado nenhum". O problema não era a
quantidade de detalhe: era não haver ninguém ali. Um porto é uma cadeia curta de
estações, e cada estação é o trabalho de uma pessoa.

- [x] `NpcCatalog` define a cadeia — berço, pátio, pilha, estrada, portão,
      cidade, manobra — e só essas estações têm gente. Armazém, torre, porto de
      IA, portal, trem e drone são infraestrutura: funcionam, mas não são
      alguém. Cada papel responde numa linha por que existe.
- [x] Os limites visuais caíram junto (`StructureLayer.CAPS`): dois conferentes
      em vez de quatro, dois portêineres em vez de três, um drone em vez de
      dois. Comprar mais equipamento deixa o porto mais rápido, não mais cheio
      de estranhos.
- [x] `NpcRoster` guarda a pessoa por vaga (`"sts#0"`), não pelo sprite: o
      operador, a data de contratação (dia do porto **e** data do calendário) e
      o total de movimentos sobrevivem a comprar terreno, prestígio e reload.
      Seção de save `npc_roster`.
- [x] `TaskBoard`: as necessidades são derivadas do estado vivo do porto, cada
      uma tem uma chave física (`pilha:bloco3`, `portao:baia1`,
      `estrada:patio47`) e cada chave tem **um** dono. Dois NPCs não pegam a
      mesma tarefa porque só existe uma chave.
- [x] O lado terrestre passou a excluir as caixas já reservadas por outro
      motorista. Antes os dois recebiam o mesmo topo de pilha e o segundo
      chegava, não achava nada e voltava com o chassi vazio.
- [x] O conferente faz ronda com motivo: berço enquanto há navio, carreta que
      acabou de estacionar, depois os blocos com estoque. Anda até o lugar,
      fica lá o tempo de conferir, credita e pega a próxima.
- [x] O portêiner só se move quando um contêiner se move:
      `BerthCallController.move_started` entrega cada transferência real a um
      guindaste livre, que acompanha aquela caixa pelo tempo exato do voo e
      estaciona quando não há nada no ar.
- [x] Tocar numa pessoa abre a ficha: nome, cargo, no porto desde, dossiê,
      função no porto, tarefa atual e movimentos. A carga tem prioridade no
      toque — navio e carreta atracada continuam sendo trabalho, nunca ficha.
- [x] Personagens especiais semeados em vaga fixa: **Alisson**, conferente de
      capacete azul, referência ao Alisson da Wilson Sons de Rio Grande; **Seu
      Valdir**, comandante de rebocador; **Dona Neusa**, despachante do portão.
      O capacete é um overlay em cinzas tingido por `modulate`, alinhado quadro
      a quadro ao corpo — só o conferente tem capacete para tingir, então só ele
      carrega cor.
- [x] Suíte `npc`: identidade persistente, uma chave um dono, o toque de
      inspeção, o rolo do casco e as tomadas de som. Inclui a checagem de que
      todo texto da tripulação existe na fonte bitmap do jogo.
- [x] Aba **EQUIPE** no Diário: a escala inteira numa lista, com cargo, tarefa ao
      vivo e total de tarefas de cada um. Especiais destacados. É o que a ficha
      individual não dá — dá pra comparar o turno.
- [ ] Turnos: a mesma pessoa de dia e de noite, com troca visível.

Aceite: dá para olhar o pátio e dizer quem está pegando do navio e levando para
a pilha; duas pessoas nunca fazem a mesma tarefa; a ficha do Alisson diz de onde
ele veio.

### Fase K — frota simultânea e escalas especiais — P1

- [x] `PortLayout` ganha berços de verdade: até três, ao longo do cais, e a
      quantidade sai da **profundidade do próprio mundo** — comprar terreno alonga
      o cais e libera o berço seguinte. Nada de constante mágica.
- [x] Os berços dividem um canal só, porque 80px de água cabem um casco de 66.
      Então **um navio manobra por vez**, entrando pela lane de fora e encostando
      no final; quem está atracado fica no lugar e o que passa desenha por cima.
      `PortWorld.ships`/`berths` são as listas; `ship`/`berth` continuam sendo o
      berço 0, que é o nome que as suítes já usam.
- [x] A frota visual voltou ao contrato do GitHub: três silhuetas, quatro
      pinturas e **um único** `ship_top.png`; todas as escalas trabalham as
      mesmas doze fileiras/24 caixas.
- [x] Feeder, Panamax e New Panamax aplicam somente escala, offset e livery ao
      casco 66x232. Classes adicionadas depois continuam aceitas por rotas e
      saves como aliases, sem criar novos PNGs.
- [x] Toda classe está em alguma rota: `barge` na cabotagem, `handysize` no
      Caribe/Atlântico, `ULCV` no Transpacífico. Sem isso três classes novas eram
      navios que ninguém veria — a suíte `route` agora falha se sobrar alguma.
- [x] O portêiner mais perto é que pega o movimento, senão a caixa voava debaixo
      de um guindaste a 200px de distância. Rebocador e conferente seguem o berço
      que está sendo trabalhado.
- [x] O chip do HUD diz de qual berço está falando; o rail diz "berço 2/3".
- [x] ETA de verdade: a espera de cada berço virou um número (`berth_report()`)
      em vez de um `await` que ninguém consegue ler. Conta o turnaround, o
      espaçamento do canal e quem está na frente na fila.
- [x] Cada berço com sua linha no rail em paisagem: classe, progresso, ou "em
      12s" quando está vazio. O berço em foco fica no card grande.

Aceite: três navios atracados, cada um com sua carga e seu tamanho; tocar num
deles trabalha aquele e não o primeiro.

### Fase L — contratos viram evento — P1

O Diário tinha um card de contrato no topo da aba de metas: um contador quieto,
em cima de objetivos que não tinham nada a ver com ele. Saiu.

- [x] Contrato virou **escala especial**: rara (minutos de cooldown), com alerta
      que interrompe, aceitável ou recusável, e com prazo pra responder.
- [x] Aceitar reserva a próxima escala de um berço livre: o navio especial
      **chega pelo canal**, com pintura que nenhuma escala normal pode sortear.
- [x] Quando ele atraca, abre o minigame: uma garra que corre o poço e um toque
      pra soltar o contêiner. A caixa cai onde tu largou, a torre inclina, e o
      que sobra de encaixe é o alvo da próxima. Três erros ou o relógio zerado =
      perdeu. Estilo fase surpresa: acelera a cada caixa, pitch subindo, tremida
      na tela, "PERFEITO!" com combo.
- [x] Ganhou: 10x a produção por 15s, ou 2x por 2min, ou uma bolada — sempre
      precificado em **segundos da renda do próprio porto**. Perdeu: multa ou
      produção a 50% por 45s.
- [x] Burst nunca sobrevive a reload (guardar um 10x não é prêmio, é exploit) e
      multa nunca joga a carteira pra baixo de zero.
- [x] Escala interrompida por reload/prestígio não paga nem cobra; minigame pego
      no meio volta como minigame a jogar.
- [x] Suíte `special`: raridade, recusa, expiração, casco exclusivo, limites do
      prêmio e da multa, e o jogo sendo ganho, perdido e estourado no tempo.
- [x] Segundo minigame: **labirinto do pátio**. Verbo diferente do empilhar —
      navegação em vez de timing. Grade 9x9 escavada do seed da própria escala
      (mesma escala, mesmo pátio), contêineres espalhados, berço trancado até
      achar todos, e relógio. Direcional de quatro teclas com seta girada por
      lado, mais setas/WASD. Duas escalas novas usam ele.
- [x] `MinigameBoard`: a moldura (scrim, placar, grito, encerramento) é uma só,
      então o jogador aprende onde fica o relógio uma vez. Cada jogo entrega só o
      miolo.
- [x] Placar de escalas especiais no Diário, na aba nova **EQUIPE**.
- [ ] Terceiro minigame (prumo do gancho).

Aceite: aparece de vez em quando, dá pra recusar, é difícil, e ganhar muda o
número na tela na hora.

### Fase M — cordas, chuva e profundidade — P1

O playtest apontou o cabo de amarração: duas linhas retas pretas saindo do nada.

- [x] Corda de verdade, gerada: tile de 6px com espiral que fecha na emenda, mais
      um nó de laço pro bollard. `Line2D` texturizado, não linha desenhada.
- [x] Duas amarras — lançante de proa e de popa — saindo dos
      **cabeços que o sprite do casco realmente desenha** e chegando nos
      **bollards que o cais realmente tem** (`PortLayout` virou dono dos dois, e
      o teste falha se uma corda cair perto de um bollard em vez de nele).
- [x] Catenária rasa: corda de amarração sob tensão quase não pendura. A primeira
      versão tinha quatro cabos de sisal claro com barriga generosa que se
      cruzavam — viraram espaguete. Corda alcatroada escura, reta o bastante.
- [x] Animação de lançar, escalonada por cabo, e de largar antes de sair. Estado
      "atracado" é instantâneo; recolher é animação — berço não espera animação.
- [x] Chuva: fio d'água diagonal, respingo onde cada gota cai (cada gota carrega a
      altura em que aterrissa, senão só respinga na borda do mundo), céu mais
      frio e os mastros acendendo de tarde.
- [x] Sombra de contato sob o casco: o navio passa a pousar na água em vez de
      parecer adesivo. Luz vem de cima-esquerda, como em todo o resto do jogo.
- [x] Navio **cortando** a água: onda de proa saindo da roda em ângulo fixo,
      colarinho de água revolta arrastado pelas laterais do casco, e o V de popa
      com cristas transversais encurvadas pra trás.
- [x] Mais coisa com sombra: caixa no chão do pátio e cabeços do cais. Luz de
      cima-esquerda, como em todo o resto. **Convés não** — as fileiras ficam a
      11px e a caixa tem 13, então a sombra cai em cima da caixa de baixo e o
      porão vira faixa escura. Tentei, ficou feio, saiu.
- [x] Água trabalhada por **todo** casco, parado ou não: uma marola corre ao longo
      de cada navio, com pico alguns pixels pra fora (os três primeiros ficam sob
      a sombra do próprio casco). Antes a superfície só se mexia nos cinco
      segundos de uma atracação, que é dizer nunca.
- [x] O meio-comprimento passado ao shader acompanha a escala aplicada ao casco
      único, não o envelope fixo do berço.
- [x] O "+N TEU" do toque estava lá e ninguém via: texto de 10px quase branco
      com contorno de um pixel, em cima de um porto cheio de contêiner colorido.
      Virou número grande, cor quente, contorno grosso, com estalo de escala ao
      nascer — e o crítico é o dobro do tamanho, em dourado. A captura `reward`
      falha se nenhum número aparecer.
- [ ] Reflexo do casco na água parada.
- [ ] Poças que crescem no pátio enquanto chove.

### Fase N — otimização — P1

- [x] `ContainerYard._slot_is_reserved` era O(reservas) chamado dentro de laços
      que já percorrem todos os slots — O(slots × reservas) num porto comprado
      inteiro. Virou contador por slot, O(1).
- [x] `road_pickup_slot` montava e **ordenava** a lista de todos os slots
      ocupados. Isso era perguntado uma vez por caminhão por frame pelos contornos
      de interação. Virou uma passada só.
- [x] Contornos de interação a 8 Hz em vez de 60 (o ponteiro em movimento ainda
      atualiza no próprio evento). Cada refresh percorre o pátio inteiro por navio
      e por caminhão.
- [x] O portão só pergunta "que baia trabalhar" quando um movimento está de fato
      vencido, não duas vezes por frame pra decidir se acumula.
- [x] A linha de berço do rail buscava um nó com nome automático e **errava todo
      frame**; spam de erro custa mais que a linha desenha.
- [ ] Medir de verdade: `tools/capture/perf.tscn` precisa de janela em foco. Numa
      janela sem foco o mesmo build mediu 144 fps num run e 13 no seguinte, então
      os ganhos acima são algorítmicos e provados por teste, não cronometrados.

### Fase O — o relógio do porto e os instrumentos — P1

- [x] Relógio no canto, no estilo do de Stardew mas de porto: **disco de céu
      pintado que gira** atrás de um aro de latão com ponteiro fixo em cima. Sol
      nasce pela esquerda, cruza o topo ao meio-dia e se põe pela direita; noite
      com lua e estrelas embaixo; faixas de amanhecer e entardecer nas horas
      certas — as mesmas do `TimeManager`, então quadro e relógio concordam.
      Um mostrador com ponteiro diz a hora; uma janela pro céu diz o que a luz
      está fazendo sem ser lida.
- [x] Hora em âmbar, dia em tom apagado, glifo do tempo (sol, lua, nuvem, chuva,
      névoa) e a força do vento em três pips. Revisado em 30/07/2026: a placa de
      ardósia, o cartão do dia e a caixa de madeira em volta saíram, e o vento
      deixou de gastar onze caracteres da barra em palavra.
- [x] Fica encaixado na ponta direita do pórtico, que por sua vez acompanha o
      **mundo** e não a janela: em tela larga a direita é o rail de comandos, e um
      relógio ali sentaria em cima das teclas.
- [x] `TimeManager` ganhou `wind` e `overcast`, sorteados por dia. Como a chuva,
      são só aparência: a neblina já carrega a penalidade de throughput.
- [x] Birutas laranja-e-branco em três estados de enchimento (com rajada
      escalonada) e galhardetes de pano nas alturas do vento. Ficam onde o
      terminal tem chão livre — nunca no trilho do portêiner nem na faixa de
      rolamento.
- [ ] Maré subindo e descendo na linha d'água.
- [ ] Estação/mês no relógio, além do dia.

### Fase J — variedade sonora — P2

- [x] Seis tomadas do contêiner aterrissando e quatro do spreader pegando a
      caixa, sorteadas em saco embaralhado com escada de pitch: nem a tomada nem
      o pitch repetem em sequência. Sob automação isso toca várias vezes por
      segundo e uma amostra só soava como bug.
- [x] O casco agora **rola**: a caixa que sai ou entra numa fileira faz o navio
      inclinar para aquele bordo e voltar pelo outro antes de assentar. Antes era
      um empurrão sem sinal que decaía para zero, então o berço em operação ficava
      com banda permanente para o mesmo lado.
- [x] Buzina em quatro tomadas e blip de interface em três. Todo navio soando
      igual é a única coisa que um porto nunca faz, e a buzina toca em toda
      chegada e toda partida.
- [ ] Famílias para marreta e cancela.

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

### Fase Q — retrato travado, casco virado, carreta refeita — P0

Quatro pedidos do playtest de 30/07/2026, terceira passagem.

- [x] **O jogo é retrato sempre.** `PortraitFrame` (autoload) trava a proporção em
      2:3 e coloca **barras laterais** numa janela mais larga; numa tela mais alta
      que 2:3 — todo telefone moderno — ele solta a altura e preenche. Um valor só
      de `stretch/aspect` não faz isso: `expand` vira paisagem no desktop e `keep`
      põe faixa em cima e embaixo de qualquer celular. A regra real é "limite a
      proporção no retrato", que são os dois modos trocados no cruzamento.
- [x] Por decisão visual, o casco voltou ao desenho atual do GitHub, com a proa
      no topo, a acomodação na popa e o convés começando em y=44.
- [x] A camada `ship_windows` foi retirada; o casco único mantém somente as
      claraboias pintadas no próprio sprite e as luzes operacionais do runtime.
- [x] O rastro do shader voltou a ler a proa em `-y`, sem o espelhamento criado
      para a versão temporária de proa para baixo.
- [x] **A carreta foi refeita do zero.** Eram dois bugs com a mesma raiz: o
      caminhão andava na direção do próximo waypoint enquanto a rotação do corpo
      só *tendia* pra lá, então em toda curva o corpo apontava pra um lado e o
      veículo ia pro outro — a caixa em cima parecia deslizar um tempo atrás das
      rodas. E carregava as caixas num sprite único cujo leito tinha 28 px pra
      29 px de carga, então a segunda sobrava pra fora da traseira.
- [x] Agora são **dois corpos**: cavalo e semirreboque com sprites próprios
      (`veh_truck_cab`, `veh_truck_chassis`), articulados no quinto-roda — o
      chassi arrasta o eixo traseiro e vira atrás do cavalo como um semirreboque
      de verdade. E a velocidade é **sempre ao longo do nariz**, então o conjunto
      fisicamente não consegue andar de lado: atraso de carga deixou de ser uma
      coisa a calibrar e passou a ser uma coisa que não dá pra expressar.
- [x] Freio de curva com antecedência (`_corner_throttle`) e aceite de waypoint
      "passou por trás do nariz" — sem o segundo, uma marca que o veículo raspa
      vira rotatória e ele gira nela pra sempre.
- [x] **Tela inicial no formato do mockup**: placa grande, JOGAR / CONTINUAR —
      DIA n / AJUSTES, quatro teclas de canto (FEEDBACK, SITE, COMUNIDADE,
      CRÉDITOS) e o rodapé com versão e estúdio. CONTINUAR só existe quando existe
      pra onde continuar; o terminal é lembrado em `UserPreferences`, não num save,
      porque a tela tem que responder "continuar qual?" antes de carregar
      qualquer perfil.

Pendente nesta fase:

- [ ] A arte de fundo da tela inicial (`ui_title_port.png`, 160×240) é bem menos
      densa que o mockup e o recorte COVERED aperta o horizonte num telefone alto.
- [ ] O reboque não tem para-choque traseiro articulado nem estabilizadores; o
      chassi é uma peça só.

### Fase R — a gangue é uma só — P1, entregue em 04/08/2026

A maior lacuna do jogo, e ela estava escondida atrás de um número que ninguém
tinha conferido: `BerthCallController.auto_rate()` devolvia a taxa **inteira do
porto para cada berço, independentemente**. Três navios atracados multiplicavam
as mesmas máquinas por três. Não era só balanço furado — era a razão de a
automação não abrir decisão nenhuma: se cada berço já ganha tudo, não existe
pergunta sobre para onde mandar a gangue.

Agora existe uma gangue só, e o jogador dá a ordem permanente:

- **EQUILÍBRIO** — divide entre todos os berços trabalhando. É o padrão e
  reproduz os números antigos exatamente, então nenhuma run existente foi
  mexida.
- **CONCLUIR** — quem está mais perto de zarpar leva tudo. Mais escalas por
  hora, mais bônus de partida.
- **MAIOR NAVIO** — o maior casco primeiro. Menos escalas, cada uma vale mais.

- [x] `CraneAllocation` (`scripts/cargo/crane_allocation.gd`): classe pura e
      estática. O total gasto é sempre `taxa × berços trabalhando` — concentrar
      é escolha de **onde**, nunca multiplicador. Um pool maior que o teto de um
      berço escorre para o próximo em vez de evaporar, senão concentrar seria
      silenciosamente pior que dividir.
- [x] Berço vazio nunca recebe guindaste: contá-lo diluiria a gangue num
      pedaço de cais sem navio.
- [x] `PortWorld._allocate_cranes` é o único chamador. O controlador de berço
      só obedece a fatia — e um controlador tickado sozinho (as suítes, um porto
      de um berço só) continua com a taxa inteira, então ordem permanente só
      pode mudar como uma gangue **compartilhada** é gasta.
- [x] Persistido no save e sobrevive ao prestígio: é como o porto é operado, não
      progresso. Save anterior à feature continua fazendo o que fazia.
- [x] Aba **ORDENS** na loja, que só aparece quando o cais tem mais de um berço.
      Um porto de primeira hora não tem alocação pra decidir, e regra 10 diz que
      profundidade se revela.
- [x] A linha do berço mostra a taxa que **aquele** berço recebeu, então trocar
      a ordem tem efeito visível na hora.
- [x] Suíte `automation`: os três modos, o total conservado, o escorrimento no
      teto, o berço vazio, a ordem desconhecida e o reload.

O que continua aberto da regra 5: **auto-compra configurável** e **política de
pátio**. A alocação era a primeira das três e a única que já tinha um número
errado esperando.

### Ordem de execução

A → B → D → E → C → **P** → F → G → H.

O cromo quebrado e a falta de tela inicial são o que o jogador vê primeiro, e
automação com bônus de partida é o que muda o jogo com menos código. A frota
múltipla (C) vem depois do polimento de movimento (E) de propósito: não faz
sentido multiplicar por três um navio que ainda atraca de ré.

A fase P entrou depois do segundo playtest e furou a fila do mapa-múndi (F).
A razão está em [`docs/design/principios.md`](docs/design/principios.md): comprar
sem ver o que mudou é o erro que mais mata clicker, e rota nova num porto onde a
compra não tem corpo é conteúdo empilhado sobre um buraco. O que sobrou da P —
lança do reach stacker, semirreboque articulado, prioridade no apron,
empilhamento entre pilhas vizinhas — é polimento e pode andar em paralelo com F.

### O que continua sendo a maior lacuna

**Automação abre uma decisão; deveria abrir três.** A Fase R entregou a
alocação da gangue entre os berços — a primeira coisa no jogo que a automação
manda o jogador escolher em vez de só substituir o toque. Faltam as outras duas
da regra 5 de `docs/design/principios.md`:

- **auto-compra configurável** — um capataz que compra sozinho acima de uma
  reserva escolhida. É o que transforma a sessão longa de "clicar em comprar"
  em "decidir a política de compra";
- **política de pátio** — estoque contra giro, isto é, quantas caixas a coleta
  rodoviária protege. O número existe (`RoadCargoPolicy.MIN_OPERATIONAL_STOCK`,
  24 caixas) e é constante; virá do simulador de balanceamento, não de uma
  edição de uma linha.
