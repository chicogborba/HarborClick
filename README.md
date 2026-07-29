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
               critters, port_camera
  ui/          ui_theme, port_icon, hud, shop, shop_card, tutorial, Diário,
               capital, notification_coordinator, toast_layer, settings_panel,
               offline_popup
tools/
  venv/        Python + Pillow
  sprites/     geradores de pixel art, fonte e UI
  audio/       synth chiptune + geradores de SFX/música
  capture/     harness de screenshot: roda o jogo de verdade em toda a matriz
               de resolução e falha se algum overlay sair do viewport
tests/         regressão headless de core/save, UI, tráfego, notificações e
               100 escalas de carga
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
- **Tráfego** — via de serviço de mão dupla separada em duas colunas, faixa de
  rolamento reservada por veículo e distância de seguimento. Um veículo travado
  devolve o serviço em 12 s em vez de segurar a faixa e matar de fome o resto.
- **Notificações** — `NotificationCoordinator` decide o que merece atenção:
  estado rotineiro (fase do berço, chegada) fica só no chip e no histórico,
  repetições dentro de 8 s viram contagem numa faixa só, um toast por vez e no
  máximo um por segundo, prioridade fura fila.
- **Save** — envelope JSON v2 em `user://save.json`, escrita temporária,
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

## Plano de evolução — auditoria de 29/07/2026

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

### O que já foi concluído

- [x] Preservar e publicar a versão-base no branch `main` do
      [repositório HarborClick](https://github.com/chicogborba/HarborClick).
- [x] Criar `.gitignore` para cache do Godot, probes, previews e exports.
- [x] Documentar clone, execução no editor, linha de comando e validação
      headless.
- [x] Abrir e executar o projeto no Godot 4.7.1 sem erro de runtime.
- [x] Auditar os 29 scripts, a cena principal, economia, save, input, UI e
      fluxo de carga.
- [x] Inspecionar o jogo em retrato, telefone alto e desktop 16:9.
- [x] Preservar sem alteração o save, as capturas e a configuração de áudio do
      usuário usados durante a inspeção.
- [x] Pesquisar padrões de clickers/idle conhecidos e feedback visual em
      camadas.
- [x] Publicar este roadmap com prioridades e critérios de aceite.

Nenhuma das features abaixo está sendo apresentada como pronta.

### Diagnóstico da versão-base

| Área | Evidência encontrada | Efeito no jogador | Direção |
|---|---|---|---|
| Escala da tela | Mundo, câmera, névoa e overlays assumem 320×480 | No desktop sobra área cinza e o porto fica minúsculo; em telefone alto, conteúdo da loja pode aparecer fora da folha | `ResponsiveShell` e câmera por perfil |
| Contador TEU | O label central muda de largura e o painel pulsa a cada emissão; CPS emite todo frame | HUD “samba” quando o sufixo ou número muda | Slot numérico fixo, alinhado à direita, atualização visual limitada |
| HUD | Placa de 274×58 ocupa cerca de 86% da largura-base | O contador domina a tela | Placa compacta no canto esquerdo e status do navio separado |
| Loja | Folha clara de tamanho/posição fixos, sem backdrop | Muito luminosa, presa à esquerda no PC e não fecha ao tocar fora | Bottom sheet roxo no mobile; drawer lateral no desktop |
| Ajustes | Gear absoluto 26×26 e modal/dim de 320×480 | Ícone desalinhado, alvo pequeno e bloqueio parcial no PC | Botão dedicado de 44 px e modal `full_rect` |
| Notificações | Navio, tutorial, gato e milestones usam o mesmo toast; até três faixas grandes | Informação rotineira compete com conquistas | Estado rotineiro no HUD; um toast priorizado e histórico |
| Carga | Navio descarrega 24 e carrega apenas 10; pátio não tem tipo de carga | A mesma caixa pode “sair e voltar” e o navio parte incompleto | Manifestos de importação/exportação e transações |
| Clique | TEU é pago antes de confirmar a movimentação | Clique inválido pode render moeda | Recompensa somente no commit da carga |
| Pátio | Save novo começa vazio; pátio cheio apaga uma pilha aleatória | Primeira cena parece morta e carga pode sumir | Estoque inicial de exportação e capacidade sem descarte oculto |
| Tráfego | Veículos grandes compartilham spawn e caminho sem distância mínima | Sobreposição e escala estranha | Veículos 25–35% menores e coordenador de faixas |
| Navios | Um casco, uma capacidade e uma silhueta | Escalas repetitivas | Catálogo data-driven por classe, paleta e rota |
| Economia | Custos sobem 15%, mas nove estruturas tardias não têm upgrades próprios | O início anda e depois vira um deserto de horas/dias | Simulador, milestones de quantidade e upgrades para toda estrutura |
| Prestígio | Primeiro reset exige `1e12` e concede apenas +2%; não há confirmação | Repetição quase tão longa quanto a primeira run e risco de toque acidental | Meta-progressão perceptível, modal e reconstrução do mundo |
| Save | JSON é sobrescrito diretamente, sem versão, migração ou backup | Risco maior em background mobile e storage web | Save v2 atômico e recuperável |
| Atmosfera | Água já tem swell/ripples/glints, mas sem wake, espuma ou reação ao casco | Boa base, pouca presença | Shader em camadas, efeitos locais e orçamento mobile |

#### Gargalos de economia medidos

O clique-base tem valor esperado de 1,18 TEU antes de upgrades. A primeira
unidade usa `custo_base × 1,15^quantidade`; a unidade 50 já custa cerca de
1.084× o preço-base e a 100, 1,17 milhão de vezes. Não existem compras
x10/x25/MAX.

| Estrutura | Retorno da primeira unidade, sem upgrade |
|---|---:|
| Empilhadeira | 100 s |
| Estivador | 150 s |
| Cavalo mecânico | 138 s |
| Reach stacker | 255 s |
| Transtêiner RTG | 8,3 min |
| Portêiner STS | 16,7 min |
| Armazém | 42,7 min |
| Rebocador | 2,1 h |
| Trem | 5,45 h |
| Guindaste flutuante | 13 h |
| Alfândega | 27,8 h |
| Torre | 59,8 h |
| Drone | 109,8 h |
| Porto IA | 201 h |
| Portal | 344 h |

Uma simulação otimista da versão-base coloca `1e12` TEU em aproximadamente
47 horas de jogo ativo ou cerca de dois dias no melhor caso passivo. O primeiro
prestígio reduz a próxima jornada em apenas ~2%. A correção não será um bônus
arbitrário: a curva será simulada até cumprir as metas de sessão descritas na
Fase 3.

#### Bugs e dívida técnica a remover antes de expandir

- [x] Impedir a renovação infinita do bônus ×7 ao tocar repetidamente no gato.
- [x] Implementar ou remover `radar_neblina`, hoje consultado mas ausente no
      banco de upgrades.
- [x] Corrigir milestones carregados do JSON com tipo inconsistente e impedir
      duplicatas.
- [x] Reconstruir prédios e HUD no mesmo frame do prestígio.
- [x] Fazer `wipe()` também limpar boost, neblina e todos os estados de sessão.
- [x] Aplicar a regra de desbloqueio de upgrade dentro de `GameState`, não só
      na UI.
- [x] Parar de apagar pilhas silenciosamente quando o pátio lota.
- [x] Usar a capacidade real declarada pelos terrenos.
- [x] Parar de duplicar árvores, arbustos e cones a cada expansão.
- [x] Remover referências de import antigas sem arquivo-fonte
      (`tile_dirt`, `tile_asphalt`, `tile_concrete`, `tile_asphalt_lane`,
      `ship_feeder` e `fender`).
- [x] Corrigir câmera/inputs: A/D hoje deslocam o eixo vertical e zoom foi
      declarado, mas não implementado.

### Síntese da pesquisa

O plano não copia a aparência de outro jogo; replica mecanismos que sustentam
clareza, retenção e prazer de interação.

| Referência | Padrão útil | Aplicação no HarborClick |
|---|---|---|
| [Quest for Progress — matemática e design de idle games](https://www.gdcvault.com/play/1023863/Quest-for-Progress-The-Math) | Geradores, custos e camadas precisam ser modelados como sistema, não balanceados carta por carta | Simulador econômico, metas de tempo e testes de regressão |
| [Estudo de engajamento em idle games](https://escholarship.org/content/qt0b07v51w/qt0b07v51w.pdf) | Objetivos claros, progresso contínuo e features que aparecem no mundo sustentam engajamento; contexto mobile e PC não é idêntico | Próximo objetivo no HUD, novidades visíveis e layouts próprios |
| [Cookie Clicker](https://play.google.com/store/apps/details?id=org.dashnet.cookieclicker) | Grande trilha de upgrades/conquistas, progresso offline, ascensão e eventos reconhecíveis | Conquistas acompanháveis, prestígio que muda a run e Golden Ship |
| [Egg, Inc.](https://apps.apple.com/us/app/egg-inc/id993492744) | Veículos variados, missões, coleção e mais de uma camada de prestígio dão forma visual aos números | Rotas, classes de navio, contratos e evolução visível do porto |
| [Análise de feedback visual inspirada em Balatro](https://blakecrosley.com/guides/design/balatro) | Movimento só ajuda quando combina com a linguagem e o ritmo do jogo | O protótipo de contagem rolante, shake, pulso e vibração foi rejeitado em playtest; HarborClick mantém contador instantâneo e feedback discreto |
| [Godot: múltiplas resoluções](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) | Stretch, anchors, safe area e composição devem ser escolhidos para o formato, não apenas para um viewport-base | Perfis retrato e paisagem testados por matriz |
| [Godot: exportar para Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) | Web exige renderer compatível e cuidados específicos com armazenamento e ciclo de vida | Preset web, persistência testada e export/import manual do save |

Os padrões comuns que entram no design são:

- resposta imediata para todo toque válido;
- um próximo objetivo legível sem abrir três menus;
- novidade a cada poucos minutos na primeira hora;
- crescimento ativo e passivo que se alimentam, sem uma simulação falsa;
- reset que acelera a recuperação e abre uma decisão nova;
- eventos raros previsíveis o bastante para não parecerem injustos;
- retorno offline resumido, nunca uma chuva de toasts;
- coleção/conquistas como memória de carreira;
- números grandes estáveis, legíveis e prazerosos de acompanhar.

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

### Roadmap de implementação

#### Fase 0 — baseline e descoberta — concluída

- [x] Snapshot da versão recebida antes de qualquer alteração funcional.
- [x] Repositório remoto e instruções de execução.
- [x] Auditoria visual mobile/desktop.
- [x] Auditoria de economia, save, UI, mundo e carga.
- [x] Pesquisa de padrões do gênero.
- [x] Roadmap e critérios de aceite.

#### Fase 1 — fundação confiável e shell responsivo — P0

- [x] Criar testes determinísticos para economia, formatação numérica, cargo,
      save e eventos.
- [x] Criar cenas/probes de screenshot para toda a matriz de resoluções
      (`tools/capture`, com asserção de contenção no viewport).
- [x] Implementar save v2 com `save_version`, migrações, temporário, troca
      atômica, backup e recuperação.
- [x] Salvar em compra importante, expansão, prestígio, pause/background,
      fechamento e reload web.
- [x] Separar `run_teus`, `all_time_teus`, estatísticas de carreira e moeda
      meta.
- [x] Criar `ResponsiveShell` e perfis retrato/paisagem.
- [x] Fazer mundo, névoa, modais e input usarem o viewport real.
- [x] Implementar HUD compacto e contador sem reflow.
- [x] Refazer loja escura com outside click/Back/Escape e drawer desktop.
- [x] Refazer gear e Ajustes com foco, safe area e opções de movimento,
      números flutuantes, UI scale e fullscreen.
- [x] Unificar gesto mouse/touch: tap, drag e compra no release.
- [x] Criar `NotificationCoordinator` e remover toasts rotineiros.
- [x] Corrigir todos os bugs/dívidas listados antes desta fase ser encerrada.

Aceite da fase:

- Godot inicia sem erro nem referência de asset quebrada;
- 100 gestos de scroll na loja produzem zero compras acidentais;
- tocar fora fecha a loja sem interagir com o porto;
- contador passa pelo teste 0→`1e15` sem deslocamento;
- todas as resoluções P0 ficam sem cinza descoberto, corte ou overlay parcial;
- save corrompido recupera o backup e uma migração não duplica progresso.

#### Fase 2 — carga verdadeira e porto coerente — P0

- [x] Implementar `CargoUnit` e inventários de importação, exportação e
      trânsito.
- [x] Dividir o pátio em setores funcionais de importação/exportação.
- [x] Semear exportação inicial num save novo.
- [x] Implementar `BerthCallController` e ciclo 100%→0%→100%.
- [x] Pagar TEU somente depois do commit da transferência.
- [x] Persistir manifesto, fase, reservas e caixas em voo.
- [x] Impedir partida parcial ou antes da aterrissagem da última caixa.
- [x] Fazer caminhões retirarem importação e entregarem exportação.
- [x] Preservar UID, cor e rota em todo o percurso da caixa.
- [x] Trocar descarte silencioso por fila, bloqueio legível ou expansão.
- [x] Implementar `TrafficCoordinator` e reduzir veículos em 25–35%.
- [x] Fazer RTG/STS animarem jobs reais ou um modo ocioso claramente
      cosmético — o portêiner só balança com navio no berço e inverte o arco
      quando o berço está embarcando; o transtêiner só roda sobre bloco com
      caixa, e a caixa que ele carrega tem a cor de uma que está mesmo lá.
- [x] Fazer terreno desbloquear capacidade/geometria declarada de verdade.

Aceite da fase:

- 100 escalas automatizadas, inclusive a 60 taps/s, sem UID duplicado ou
  perdido;
- importação descarregada nunca reembarca no mesmo navio;
- clique sem transferência válida rende zero;
- todo navio parte com `loaded == capacity` e zero caixas em voo;
- salvar/reabrir no meio de cada estado reconcilia exatamente o manifesto;
- comprar todos os terrenos não duplica props nem apaga carga.

#### Fase 3 — primeira hora, economia e carreira — P1

- [x] Criar simulador de balanceamento com cenários ativo, híbrido e offline.
- [x] Rebalancear custos/CPS para cumprir as metas de progressão.
- [x] Criar upgrades específicos para as 15 estruturas.
- [x] Adicionar milestones de quantidade 10/25/50/100.
- [x] Adicionar compra x1/x10/x25/MAX com preço e ganho total claros.
- [x] Mostrar impacto de compra e próximo objetivo, sem poluir a tela.
- [x] Refazer tutorial com spotlight nos alvos, termos consistentes e replay.
- [x] Criar 30–40 conquistas iniciais: TEU, escalas, estruturas, carga,
      críticos, eventos, rotas, terrenos e coleção.
- [x] Criar Diário do Porto, progresso fixável e estatísticas de carreira.
- [x] Agrupar progresso offline numa única tela.
- [x] Refazer prestígio com confirmação, ganho perceptível e árvore de escolhas
      para throughput, clique, offline, rotas e eventos.
- [x] Garantir reconstrução visual e save imediato no prestígio.
- [x] Adicionar contratos curtos de sessão depois que a curva-base estiver
      estável.

Aceite da fase:

- metas de 10 s, 30 s, 60 s, 5 min e 60–120 min cumpridas pelo simulador;
- primeiro prestígio recupera o pico anterior 3–5× mais rápido;
- nenhuma estrutura tem payback fora da banda definida para seu tier;
- save antigo recebe conquistas retroativas sem repetir recompensa;
- tutorial é concluível por touch, mouse e teclado sem encobrir o alvo.

#### Fase 4 — porto vivo e variedade visual — P1 — pausada

Estado em 29/07/2026: o pacote visual que já estava em desenvolvimento foi
concluído, testado e publicado. A fase fica pausada aqui; nenhum item seguinte
deve ser iniciado sem uma nova rodada de direção.

Decisão de playtest: contagem rolante/interpolada, `+N` no HUD, pitch chain,
shake de câmera, pulso, flash e vibração deixaram a leitura pior e foram
removidos integralmente. O contador TEU volta a refletir o valor imediatamente,
com geometria fixa e sem movimento adicional.

- [x] Preservar o feedback simples anterior de toque, compra, marco e prestígio.
- [x] Criar três perfis de silhueta/capacidade e quatro paletas de navio.
- [x] Persistir a variante visual e impedir três repetições idênticas seguidas.
- [x] Fazer wake existir apenas na chegada/saída e parar completamente no
      berço.
- [x] Adicionar espuma no cais, splash e bandas de profundidade à água.
- [x] Reaproveitar os assets existentes de espuma, splash e wake.
- [x] Criar níveis automáticos low/medium/high para shader e sprites de água.
- [x] Corrigir o cartão do tutorial para permanecer compacto e fugir do alvo.
- [x] Proteger chamadas de áudio feitas antes de o pool terminar de iniciar.
- [ ] Aumentar a composição útil do porto — a faixa de terra não comprada e o
      vazio à esquerda ainda ocupam cerca de um terço da tela. A **leitura das
      faixas** já foi feita: a via de serviço tem eixo pintado e duas mãos.
- [ ] Reaproveitar boia, nuvens, lua e estrelas sem poluir a leitura.
- [ ] Adicionar detalhes ociosos ligados ao estado real: trabalhadores,
      iluminação, sinalização de setor e manutenção.

Aceite deste pacote:

- [x] contador TEU instantâneo, estável e sem shake, vibração ou pulso;
- [x] catálogo determinístico com 12 combinações e persistência no save;
- [x] wake mais lento na chegada, mais rápido na saída e desligado no berço;
- [x] espuma/splash limitados por qualidade, sem crescimento por altura;
- [x] 100 escalas e 4.800 transferências passam sem quebrar o contrato de carga;
- [ ] referência mobile e desktop sustenta 60 FPS no cenário de estresse.

#### Fase 5 — mapa, rotas e expansão meta — P2

- [ ] Criar mapa-múndi estilizado, legível no mobile e explorável no desktop.
- [ ] Criar rotas compráveis com origem, destino, ETA, licença, valor, classe
      de navio e mix de carga.
- [ ] Dar trade-offs às rotas: rápida/estável, longa/valiosa,
      arriscada/eventos, especializada.
- [ ] Fazer uma rota nova alterar navio ou ganho visível em até 1–2 escalas.
- [ ] Integrar viagem/ETA ao progresso offline.
- [ ] Criar contratos ligados a rotas sem virar lista de tarefas excessiva.
- [ ] Liberar segundo berço ou retroárea somente quando acrescentar decisão,
      não apenas mais números.
- [ ] Criar coleção de pinturas de casco, bandeiras, contêineres especiais e
      chapéus de funcionários.
- [ ] Ligar cosméticos a conquistas, rotas e eventos, com bônus econômicos
      pequenos ou inexistentes.

Aceite da fase:

- comprar uma rota muda o mundo e a economia dentro de duas escalas;
- cada rota tem pelo menos uma vantagem e uma renúncia compreensível;
- trocar rota não perde nem duplica manifesto;
- mapa, coleção e contratos são totalmente utilizáveis com uma mão.

#### Fase 6 — eventos raros e personalidade — P2

- [ ] Criar scheduler determinístico com cooldown, janela, pity, seed e save.
- [ ] Criar Golden Ship com silhueta/áudio próprios.
- [ ] Limitar sua recompensa a uma banda relativa à economia — ponto inicial:
      1–3 min da CPS atual ou boost curto — e validar no simulador.
- [ ] Criar OVNI que abduz um proxy visual, nunca uma caixa do inventário real.
- [ ] Prototipar baleia, tempestade, regata, inspeção aduaneira e carga
      misteriosa.
- [ ] Dar contrajogo claro a eventos negativos e nunca punir o jogador
      offline.
- [ ] Registrar eventos no Diário do Porto e ligar raridades à coleção.
- [ ] Testar reload em cada frame crítico do evento.

Aceite da fase:

- evento nunca bloqueia o berço, corrompe carga ou domina a renda horária;
- pity/cooldown sobrevivem a fechar e reabrir;
- resultado e ação possível ficam entendíveis em menos de dois segundos;
- nenhuma perda ocorre por evento enquanto o app está fechado.

#### Fase 7 — acessibilidade, web e release — P1

- [ ] Restaurar navegação por foco: Tab/setas, Enter e Escape/Back.
- [ ] Adicionar foco visível, nomes acessíveis e não depender só de cor.
- [ ] Validar contraste mínimo de 4,5:1 para texto funcional.
- [ ] Criar preset Web com renderer Compatibility/WebGL2 e build reproduzível.
- [ ] Testar persistência de `user://` no navegador e detectar storage
      indisponível.
- [ ] Criar exportação/importação manual e backup do save.
- [ ] Testar pause/background/resume no Android e iOS.
- [ ] Documentar processo de export mobile e web.
- [ ] Rodar regressão funcional, visual, econômica, performance e save.
- [ ] Preparar página web/PWA somente depois do jogo passar pela matriz.

Aceite da fase:

- jogo completo navegável apenas por teclado e apenas por touch;
- reload do browser e background mobile não perdem nem duplicam progresso;
- build web abre sem erro em navegadores-alvo e ocupa a tela corretamente;
- save pode ser exportado, apagado, importado e reproduzir o mesmo estado;
- checklist de release e instruções do README reproduzíveis numa máquina
  limpa.

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

### Ordem recomendada

Não começar por mapa, OVNI ou novas skins. A sequência que evita retrabalho é:

1. **Fase 1:** save/testes + shell responsivo + correções de UI;
2. **Fase 2:** verdade de carga e tráfego;
3. **Fase 3:** simulador, curva, conquistas e prestígio;
4. **Fase 4:** variedade visual e água, mantendo feedback discreto após o
   resultado do playtest;
5. **Fases 5–6:** rotas, coleção e eventos;
6. **Fase 7:** fechamento web/mobile e release.

O primeiro marco jogável será o fim da Fase 2: HarborClick já responsivo, com
contador estável, loja escura, save seguro, pátio dividido e todo navio
descarregando e carregando por completo. A partir daí, economia e conteúdo
podem crescer sem construir em cima de estados falsos.
