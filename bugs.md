# bugs.md — caçada de 10/11/2026

Status: **20 corrigidos em 10/11/2026** (commit da caçada de fixes), **2 eram
falso positivo** (18 e 19 — leitura da fonte 5x7 em screenshot pequeno; o 18 era
"NAVIOS ATENDIDOS" e o 19 era o corte normal de um painel com scrollbar).

Originalmente era só a lista, nada consertado:

Método: rodei a matriz de captura (7 resoluções) + closeups, inspecionei os PNGs
em `user://uishots/` (320×568 principalmente), e rastreio o código dos síntomas
reportados. Severidade: **alta** = quebra gameplay/legibilidade, **média** =
feio/confuso, **baixa** = cosmético.

## Funcionais

1. **ALTA — Contêiner ✅ CORRIGIDO** do pátio "troca de vaga" sozinho ao tocar no navio.**
   `scripts/world/container_yard.gd:435` `restore_taken()` ignora a vaga
   original (`taken.slot/level`) e chama `pick_landing_slot()`, que escolhe a
   pilha **mais rasa** (aleatória entre as empatadas). Qualquer rollback de
   transferência (toque durante embarque sem baía, voo abortado no
   `tree_exiting`, refusal) devolve a caixa numa pilha diferente — o "trocou de
   vaga sem motivo". Já existe o caminho certo (`reserve_taken_return` +
   `restore_reserved_taken` com token exato); `restore_taken` deveria usá-lo.
   Repro: encha o convés, deixe o pátio encher, toque no navio até uma
   transferência ser recusada/abortada e observe a caixa reaparecer noutra pilha.

2. **ALTA — Diálogo de prestígio ✅ CORRIGIDO** constrói a árvore de capital só no boot.**
   `scripts/ui/prestige_dialog.gd:90` chama `_build_tree()` só no `_ready`;
   `open()` (linha 94) não reconstrói. Depois do C6 (ramos Rotas/Eventos
   destravam no nível 8), eles **nunca aparecem in-game** — a captura 320×568
   mostra "CAPITAL DO PORTO - 3 RAMOS" no nível 12 (deveria ser 5). O cabeçalho
   com a contagem também é calculado uma vez. Fix: chamar `_build_tree()` (e
   reetiquetar o header) em `open()`.

3. **MÉDIA — Harness de captura ✅ CORRIGIDO** `relay_hand_off` é flaky.**
   `tools/capture/capture.gd:895` falha se nenhum contêiner for carregado ≥26 px
   em 20 s. Falhou em 1920×1080 (best 26 px) e em 390×844 (best 15 px) na mesma
   build que passa nas demais — é timing em máquina carregada, não regressão de
   código. Sugestão: deadline 20 s → 30 s ou threshold 26 px → 20 px.

## Visuais (vistos nos PNGs de 320×568)

4. **ALTA — Gaivotas voam de lado ✅ CORRIGIDO**/cambalhotando.** `scripts/world/critters.gd:106`
   faz `node.rotation = a + PI/2` (ângulo da órbita), então o sprite gira sem
   parar em vez de encarar a tangente do voo; visível como "aviãozinho de papel"
   nos shots `320x568_world/night/rain.png` (canto direito, sobre o mar).
   Deveria seguir a direção da velocidade e espelhar no eixo X ao voar pra
   esquerda.

5. **MÉDIA — Glyph tofu ✅ CORRIGIDO** (□) na linha de reconstrução do prestígio.**
   `scripts/ui/prestige_dialog.gd:166` usa `"em ~%s jogando"` — o `~` não existe
   na fonte bitmap 5×7 e renderiza como caixa: `320x568_prestige_quote.png`
   mostra "em □23min jogando". Trocar por "cerca de" ou adicionar o glifo.

6. **MÉDIA — Minijogo do labirinto ✅ CORRIGIDO** continua neon sobre preto** (sobrou do D12).
   `320x568_maze.png`: grade verde-limão sobre fundo quase preto, dentro do
   gabinete — ainda parece outro jogo. E o título aparece duplicado (título do
   board "Carga Perdida no Pátio" + letreiro dentro do gabinete com o mesmo
   texto). O plano pedia pátio top-down com a arte do jogo.

7. **MÉDIA — Barra/contador de progresso ✅ CORRIGIDO** da escala pouco legível à noite.**
   `Ship._draw`/`_update_scale_bar` (scripts/world/ship.gd): em
   `320x568_night.png` o "2/24" sobre o casco, sobre água escura, sai apagado.
   A barra em si mal aparece. Aumentar contraste do label (outline mais grosso)
   ou desenhar um fundo atrás do texto.

8. **BAIXA — Ícone de TEU ✅ CORRIGIDO** no contador vira um traço vermelho.** Em todas as
   barras superiores (`readout.gd`, `UiTheme.icon(Icon.TEU)` a 1×) o ícone
   aparece como um retângulo vermelho sem forma — parece glitch. Redesenhar o
   glifo ou usar 2×.

9. **BAIXA — Painel half-hidden ✅ CORRIGIDO** atrás do command rail no canto inferior
   esquerdo** (visível em `320x568_rail_standing.png`: um painel cinza com ícone
   de monitor espreitando atrás da tecla SHOP). Algum HUD (provavelmente
   BuildHud/BoostChips) está ancorado abaixo da área segura e o rail cobre.

10. **BAIXA — Cartão de cerimônia ✅ CORRIGIDO** de nível cobre as teclas do console** no
    320×568 (`320x568_world.png`: "Open the Port Logbook" em cima do SHOP).
    É transitório, mas no menor celular cobre o botão principal. Poderia cair
    mais alto ou não bloquear o toque (já é mouse-ignore, então só visual).

11. **BAIXA — X de fechar sobrepõe ✅ CORRIGIDO** a scrollbar** nos painéis (settings, journal:
    a trilha da scrollbar passa atrás do botão X no canto superior direito).
    E o carimbo de contagem do ARCADE encosta na scrollbar do Diário.

## Rodada 2 — caçada de UI/visual (10/11/2026, 2ª passada)

Método: inspecionei os PNGs da matriz em 390×844, 320×568, 768×1024 e
1280×720 + títulos (`title_*.png`) + crops de zoom (`crop_*.png`,
`closeup_gull.png`) em `user://uishots/`.

12. **ALTA — Brasão (âncora dourada) ✅ CORRIGIDO** do título cortado no topo em TODAS as
    resoluções.** `title_320x568.png`, `title_390x844.png`, `title_1280x720.png`:
    só a metade inferior da âncora aparece acima da placa "HarborClick" — o
    `y` do crest fica negativo (`plate.y - 0.74*crest_h`). É a primeira coisa
    que se vê no jogo.

13. **MÉDIA — Rodapé "v1.0.0 ✅ CORRIGIDO** / PORTSTACK STUDIOS" sobrepõe a arte do mundo no
    título.** Em 320/390 fica sobre grama/rua (legível), mas no 1280×720
    (`title_1280x720.png`) cai em cima do píer com contêineres e fica sujo.
    Precisa de safe-area/fundo próprio.

14. **MÉDIA — Filete vermelho fino ✅ CORRIGIDO** colado na borda direita da tela no 320.**
    Visível em `crop_bottom_rail_320.png` (à direita da tecla SETTINGS) e em
    `rail_standing.png`: uma linha vermelha vertical meio fora da área segura.
    Algum glow/borda de painel está vazando pra fora do viewport.

15. **MÉDIA — Dígitos "unlit" ✅ CORRIGIDO** do contador principal aparecem apagados.**
    `crop_topbar_320.png` ("..51.0T"), `reward.png` ("..392T"),
    `320x568_moorings.png` ("..650T"), `closeup_gull.png` ("..1197T"): os
    primeiros dígitos do readout saem escuros (segmentos "apagados" de display)
    e o valor fica difícil de ler de relance — parece artefato, não estilo.

16. **MÉDIA — Modal de "Escala Especial" ✅ CORRIGIDO** empilha em cima de qualquer painel
    aberto.** Visto em `390x844_wheel.png` (o botão SPIN da Lucky Wheel fica
    visível/atrás do modal), `390x844_journal.png`, `shop.png`, `settings.png`,
    `prestige.png`, `routes.png`, `daily.png`. O evento global abre por cima de
    tudo sem fechar o painel corrente — visualmente confuso (parece dois modais
    brigando). Ou fecha o painel aberto, ou o evento espera o modal fechar.

17. **BAIXA — Aba de terreno da loja ✅ CORRIGIDO** aparece como área grande vazia escura.**
    `390x844_shop_land.png`: abaixo do modal só há um retângulo escuro vazio.
    Pode ser estado (nível 13 sem obra nova disponível), mas parece lista não
    populada — vale checar se há um empty-state.

18. **BAIXA — Nome de conquista em latim 🚫 FALSO POSITIVO** na aba Troféus.**
    `390x844_journal_trophies.png`: "NAVIUS ALIENUIUS" — placeholder de
    localisation que vazou (deveria ser o nome pt-BR da conquista).

19. **BAIXA — Settings: typo 🚫 FALSO POSITIVO** "Makess every label..." e texto cortado na borda.**
    `390x844_settings.png`: "Makess every label and every button bigger." (falta
    o "e") e a última linha do texto do painel ("...for up to 8h") sai cortada
    na borda inferior — o painel precisa de scroll ou respiro.

20. **BAIXA — Ícones dos botões laterais ✅ CORRIGIDO** esquerdos alinhados ao topo.**
    `crop_leftkeys_320.png`: roleta colorida e prancheta ficam no topo do botão
    quadrado com vazio embaixo — não estão centralizados verticalmente.

21. **BAIXA — Formato de número inconsistente ✅ CORRIGIDO**.** Modal offline mostra
    "6600a TEU" / "1650a TEU missed" (`390x844_offline.png`) enquanto a topbar
    usa "1.01Qi" e a loja usa "1.72K" — o sufixo "a" solto (sem ponto, minúsculo)
    destoa e parece bug de formatação.

22. **MÉDIA — Contador do casco pode mostrar ✅ CORRIGIDO** valor acima da capacidade.**
    `320x568_moorings.png` mostra "29/24" no navio com a barra cheia (pode ser
    dígito unlit confundindo a leitura — investigar junto com o item 15 — mas
    se for valor real, o clamp da escala está faltando).

## Débito conhecido (não é bug novo, pra contexto)

- Textos de catálogo em pt-BR dentro de telas em inglês ("Opens with: …",
  nomes de rotas) — é o R1 (tradução de conteúdo), já documentado no plano.
- A captura roda em locale `en`, então prints misturam en/pt-BR — artefato do
  harness, não do jogo.
