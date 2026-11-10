# Plano de release — HarborClick

Escrito em 10/11/2026 a partir de uma auditoria do jogo rodando (capturas em
pt-BR de todas as telas, perfil novo incluído), do simulador de balanceamento e
de leitura do código. Este documento é para ser **executado por agentes**: cada
tarefa tem id, objetivo, arquivos, critério de aceite e dependências.

Ele substitui, em prioridade, o "Plano de evolução" do `README.md` (os itens de
lá que continuam valendo estão referenciados aqui pelo número antigo).

Regra de leitura: **Parte 1** diz o que está errado, **Parte 2** o jogo que
queremos, **Parte 3** o que cortar, **Parte 4** as tarefas por frente,
**Parte 5** a ordem e como dividir entre agentes, **Parte 6** o que é "pronto".

---

## Parte 1 — Diagnóstico

### 1.1 O que já é bom (não mexer)

- Núcleo de simulação: cada contêiner tem identidade, toda transferência é
  transação; 30 suítes headless, save versionado, 9 idiomas na interface.
- Economia medida: primeiro prestígio em ~72 min ativo, 17,5 h casual,
  recuperação pós-reset 3,6× mais rápida (`tools/balance/run_balance.gd`).
- Arte base recente: trem 1:1, contêineres com volume, navio com pintura por
  camada, paleta com hue-shift.

### 1.2 O que está ruim, com evidência

| # | Problema | Evidência |
|---|---|---|
| D1 | **Primeiro minuto quebrado.** O tutorial diz "toque no navio" com o foco em água vazia (navio ainda chegando). | captura `closeup fresh` |
| D2 | **Coisa demais, cedo demais.** No segundo zero já existem: ramal ferroviário desenhado, galpão, pórtico, roda, missões, sino, relógio, 4 teclas, 5 abas. Em 5 min o jogador tem loja, melhorias, terra, ordens, decoração, rotas, diário, roda, missões, gaivota, fretamento. | captura `fresh_played`; `GroundBaker._paint_rail_corridor` é incondicional |
| D3 | **O toque não tem graça.** Zero partículas, zero tremor de tela, zero vibração, sem combo, sem alvo especial. O navio (único alvo) ocupa ~15% da tela, na borda direita. | grep: nenhum `CPUParticles2D`, `vibrate`, `shake` de câmera, `combo` fora dos minijogos |
| D4 | **Nenhuma habilidade ativa.** Tudo que dá bônus é sorte (gato ×3, gaivota, roda, fretamento) e divide um único slot de surto. Não há botão com cooldown. | `GameState.grant_surge` |
| D5 | **Bônus invisível.** Não há indicador de turbo/frenesi no HUD — o jogador ganha ×7 e não vê timer. | `hud.gd`, `readout.gd` sem `surge` |
| D6 | **UI é texto.** Fonte 5×7 em tudo (≈8 px CSS num celular), aba Ordens é parede de texto, descrições longas com piada, poucos ícones. | capturas `shop_orders`, `charter` |
| D7 | **Pontos de entrada demais e redundantes.** 4 teclas + 5 abas + 2 teclas laterais + sino + relógio + etiqueta de taxa. Contratos, conquistas, missões e objetivo são 4 sistemas de "meta" separados. | — |
| D8 | **Comprar máquina não é decisão.** Todas na curva 1,15; build larga e alta dão a mesma pirâmide (distância 0,006). | README item 4 |
| D9 | **Recompensas ocas.** 38 conquistas só pagam cosmético/XP; 2 dos 5 ramos da árvore de capital estão mortos (Rotas, Eventos); `last_run_summary` gravado e nunca lido. | `achievement_db.gd`, `prestige_db.gd:44-53` |
| D10 | **Título poluído.** 4 botões de canto disputam com o logo; fundo é o próprio porto, ocupado; ilustrações dos perfis são isométricas (outro estilo). | captura `title`, `title_board` |
| D11 | **Mundo ilegível no zoom padrão.** Tudo pequeno, muito ruído de chão (marcas, postes, cabeços), sem hierarquia; não há zoom por pinça no celular. | `port_camera.gd` só trata roda do mouse |
| D12 | **Minijogos com cara de outro jogo.** Labirinto é neon vetorial em preto; pilha é arena vazia. Textos sem acento ("berco"). | capturas `maze`, `minigame` |
| D13 | **Áudio curto e seco.** 3 loops de 52/72/84 s num único timbre, mono 22 kHz, sem reverb, sem ambiência (mar, chuva, porto). Mudos: abrir painel, trocar aba, conquista, caminhão, guindaste, chuva, fim de escala. Sem pausa ao perder foco, sem desbloqueio de áudio na web. Pool de 10 vozes corta som. | auditoria de áudio |
| D14 | **Sem monetização.** Nenhum ponto de anúncio, nenhum serviço de ads/IAP. | — |
| D15 | **Release.** Só preset Web; catálogos só em pt-BR (README item 9); wasm 40 MB; CI de deploy parado; COOP/COEP obrigatório hoje, o que **quebra SDKs de anúncio em iframe**. | `export_presets.cfg`, `deploy/` |

### 1.3 Bugs pontuais achados na auditoria (entram em A6)

- **Progresso do navio é calculado e nunca desenhado**: `main.gd:312-331` →
  `hud.set_berth_status`, mas `hud.gd` só guarda para teste/a11y.
- **Detalhamento da taxa não fecha com toque no fundo**, só com mouse
  (`rate_breakdown.gd:33-35`).
- **Caractere inexistente na fonte**: `shop_card.gd:230` devolve "—" (vira
  quadradinho).
- **Tremores ignoram "movimento reduzido"**: `minigame_board.gd:165-172` e o
  tremor do painel da roda.
- **Alvos de toque abaixo de 44 px**: teclas da roda e das missões (32×32),
  sino (30×30), X de fechar (30×24), segmentos dos Ajustes (h=24), comprar rota
  (66×28), apagar perfil (h=24), slider (28).
- **"PULAR" e outros ~300 textos fixos em pt-BR fora do `Loc`**; só rotas estão
  em `strings_content.gd`. Maiores: `achievement_db` 76, `upgrade_db` ~60,
  `game_state` ~30, `structure_db` 30, `prestige_dialog` ~24, `port_journal` ~22.
- **Escala de UI máxima é 1,15** (`user_preferences.gd:15`) — pouco para a
  fonte atual.

---

## Parte 2 — O jogo que queremos

### 2.1 Pilares

1. **O toque é delicioso.** Tocar no navio tem de ser a melhor sensação do
   jogo: som em camadas, partícula, número, combo, vibração.
2. **Uma coisa nova de cada vez.** O porto começa quase vazio. Cada sistema
   entra com cerimônia, quando o anterior já foi entendido.
3. **O porto mostra o progresso.** Toda compra constrói algo visível; o
   terminal de 2 h não se parece com o de 2 min.
4. **Ler sem ler.** Ícone + número grande primeiro, frase depois, piada por
   último (e opcional).
5. **Sempre há um próximo passo e um motivo para voltar.**

### 2.2 Os três loops

**Segundos — o toque.**
- Toque no navio → caixa voa → TEU. Acrescenta:
  - **Ritmo de Cais (combo):** toques seguidos enchem uma barra; a cada 10
    toques o multiplicador de toque sobe 0,25 até ×3; cai após 1,5 s parado.
  - **Carga premiada:** 1 em cada ~12 caixas do manifesto é "reefer" (visível
    no convés, brilha). Tocar/descarregar paga ×5. É propriedade do manifesto,
    então respeita "carga não aparece do nada". Substitui o crítico aleatório
    invisível de 3%.
  - **Fim de escala:** navio cheio → buzina, bônus grande com contagem, zarpa.
    Hoje o bônus existe e é mudo.

**Minutos — construir.**
- Comprar máquina **inicia uma obra** (ver 2.4). A máquina chega pelo portão,
  é montada e só então rende.
- Objetivo único sempre visível ("Próximo: compre 5 Estivadores → libera
  Melhorias").
- **Habilidades do Capataz** (barra de 3 botões acima do console, cooldown):

  | Habilidade | Efeito | Recarga | Libera em |
  |---|---|---|---|
  | Turno Extra | produção ×2 por 30 s | 5 min | Nível 3 |
  | Mutirão | 10 s de toque automático (10/s) com combo travado no máximo | 4 min | Nível 5 |
  | Prático a Bordo | o próximo navio entra e sai em velocidade ×3 e paga bônus de escala ×2 | 8 min | Nível 8 |

  Cada uma melhora na árvore de capital (duração, recarga, potência). Entram no
  slot de surto existente; regra nova: habilidade **soma** com surto de sorte
  (dois slots: `skill` e `luck`), para que usar habilidade nunca seja desperdício.

**Horas/dias — crescer.**
- **Nível do Terminal** (1–30), XP por TEU produtivo, navio despachado e
  missão. É a régua que libera sistemas (2.3) e substitui o `profile_xp` solto.
- Prestígio com árvore **inteira viva** (religar Rotas e Eventos — README item 1)
  e comparação "run anterior × esta" (README item 5).
- Conquistas pagam de verdade: +1% de produção permanente cada (estilo "leite").
- Missões do dia, roda, sequência (já existem) + **Álbum de Navios** (coleção de
  cascos/pinturas/rotas vistos; completar página dá cosmético e ficha).
- Eventos raros (README item 6): navio dourado, tempestade, inspeção, baleia —
  **depois** do lançamento, não antes.

### 2.3 Liberação por nível (resolve D2)

Nada abaixo aparece antes do nível indicado — nem botão, nem aba, nem desenho
no mundo. Cada liberação tem um cartão de cerimônia ("NOVO: Melhorias") que
aponta para o botão.

| Nível | Tempo ativo aprox. | Libera |
|---|---|---|
| 1 | 0 | Navio, toque, contador. Só isso na tela. |
| 1 (após 15 TEU) | 30 s | Loja, com 1 item (Estivador) |
| 2 | 2 min | Empilhadeira; objetivo fixo |
| 3 | 5 min | Aba Melhorias; habilidade Turno Extra |
| 4 | 8 min | Cavalo Mecânico; Missões do Dia |
| 5 | 12 min | Terra (Pátio Norte); habilidade Mutirão; gaivota dourada |
| 6 | 18 min | Roda da Sorte; Diário (conquistas) |
| 8 | 30 min | Rotas; fretamentos (minijogos); Prático a Bordo |
| 10 | 45 min | Decoração; Ordens (versão simples) |
| 12 | 60 min+ | Reconstrução (prestígio) fica visível como meta |
| pós-prestígio | — | Capataz (auto-compra), Ordens avançadas |

O ramal ferroviário, o galpão e o pórtico **só são desenhados** quando a Área
Ferroviária é comprada. Lotes não comprados aparecem como terreno baldio com
placa "À VENDA".

### 2.4 Obras com tempo (ritmo + anúncio)

- Comprar máquina/terreno cria uma **obra**: tapume, guindaste de obra, barra de
  progresso sobre o local. Duração por tier:

  | Tier | Exemplos | Duração da 1ª unidade | Unidades seguintes |
  |---|---|---|---|
  | 1 | Estivador, Empilhadeira | 3 s | instantâneo |
  | 2 | Cavalo, Reach Stacker | 10 s | 2 s |
  | 3 | RTG, STS, Armazém | 30 s | 5 s |
  | 4 | Rebocador, Ramal, Flutuante | 90 s | 10 s |
  | 5 | Portão, Torre e acima | 3 min | 20 s |
  | Terreno | qualquer lote | 60 s – 5 min | — |

- Até 2 obras simultâneas (3ª entra em fila); slots extras pela árvore de capital.
- **Acelerar:** tocar na obra reduz 1 s por toque (dá o que fazer na espera);
  botão "ACELERAR ▶" conclui na hora com anúncio recompensado.
- Obras **não** contam em compra em lote ×10/×25 além da primeira unidade do
  lote; offline conclui obras. Capataz respeita fila.
- Risco: irritar. Mitigação: tier 1 quase instantâneo, toque acelera, nunca
  mais de 5 min, e o simulador ganha cenário novo que prova que o tempo até o
  prestígio sobe no máximo 15%.

### 2.5 Monetização (placeholder agora, plataforma depois)

Princípio: **só anúncio recompensado e opcional**. Nada de intersticial forçado
antes de existir retenção medida.

Serviço único `AdService` (autoload) com `show_rewarded(placement) -> bool`.
Implementação inicial `PlaceholderAdProvider`: painel "ANÚNCIO (teste) 3…2…1" e
devolve sucesso. Trocar de provedor = uma classe (`AdMobProvider`,
`H5AdsProvider`), sem tocar em telas.

| Placement | Onde | Recompensa | Limite |
|---|---|---|---|
| `wheel_spin` | Roda sem ficha | 1 giro | 5/dia, 10 min entre |
| `wheel_double` | Após o giro | dobra prêmio em dinheiro | 1 por giro |
| `minigame_retry` | Fretamento perdido | joga de novo sem multa | 1 por fretamento |
| `minigame_play` | Tecla "Arcade" no Diário | joga um minijogo na hora por um prêmio pequeno | 3/dia |
| `build_speed` | Obra em andamento | conclui a obra | sem limite, 30 s entre |
| `offline_double` | Tela de retorno | dobra o ganho offline | 1 por retorno |
| `gull_double` | Gaivota pega | dobra o prêmio | 1 por gaivota |
| `skill_reset` | Habilidade em recarga | zera a recarga | 3/dia |
| `mission_reroll` | Missões do dia | troca 1 missão | 1/dia |
| `boost_2x` | Botão no HUD | produção ×2 por 10 min (acumula até 60 min) | 6/dia |

Regras: todo placement tem teto diário e intervalo (em `AdPolicy`, puro e
testado); nenhuma mecânica **exige** anúncio; o botão de anúncio some quando o
teto bate; tudo persiste por dia local (mesmo relógio das missões).

Compras futuras (só desenhar os ganchos, sem loja real agora):
- **Passe Sem Anúncios:** toda recompensa de anúncio vira botão direto.
- **Pacote Inicial** (1 vez): fichas + cosmético + 2º slot de obra.
- **Cosméticos** (pinturas de casco, temas de HUD).
- Nunca vender TEU direto nem poder exclusivo.

Atenção técnica: SDKs de anúncio web rodam em iframe de outra origem e
**quebram com COOP/COEP**. Antes de ligar anúncio real na web: exportar o jogo
**sem threads** e remover a exigência desses headers (tarefa R4).

### 2.6 Direção de arte

- **Regras fixas** (já no `tools/README.md`): luz do noroeste, face sul visível,
  rampas com hue-shift, escala inteira, nada girado em ângulo quebrado.
- **Hierarquia:** chão quieto (menos pontilhado, menos marca), objetos com
  contorno e sombra projetada, o navio como coisa mais contrastada da tela.
- **Vida:** tudo que trabalha se mexe (carro do pórtico, cabos, rodas, braço da
  cancela, fumaça, faróis à noite, água com reflexo, espuma, chuva com respingo).
- **Peças-chave ilustradas** (via `tools/sprites/pixellab`, receita + resposta
  versionadas): arte do título, ícones de habilidade, retratos, medalhas, fotos
  dos perfis — **no mesmo estilo top-down**, não isométrico.
- **VFX:** biblioteca única `Fx` (poeira de pouso, faísca, respingo, moedas,
  confete, brilho) em pool, respeitando "movimento reduzido".

---

## Parte 3 — Cortar, fundir, manter

| Item | Decisão | Por quê |
|---|---|---|
| `scripts/ui/tutorial.gd` (Seu Waldemar) | **Fundir**: a voz do Waldemar vai para o tutorial novo; apagar o arquivo morto | `main.gd` só usa `TutorialSpotlight` |
| Mapa de metrô das melhorias (`upgrade_map.gd`) | **Remover** depois que a lista for validada em playtest | duplicado, 480 linhas, confundiu |
| Ordens (gangue/rota/ramal/capataz) | **Simplificar**: 3 predefinições com ícone; detalhe só pós-prestígio | parede de texto (D6) |
| Contratos + objetivo + missões + conquistas | **Fundir** em "Diário": aba Hoje (objetivo + missões), aba Conquistas, aba Equipe | 4 sistemas de meta (D7) |
| Botões Feedback/Site/Comunidade/Créditos no título | **Mover** para Ajustes → Sobre | D10 |
| Arrastar funcionário (segurar NPC) | **Manter** como brinquedo, mas dar 1 conquista secreta | sem efeito hoje |
| Chuva/vento/nublado | **Dar efeito leve**: chuva = +10% bônus de escala ("pressa"), som próprio | hoje só visual |
| Portal, Porto IA, Drone, Porto Orbital | **Manter** (absurdo de fim de jogo é do gênero), refazer a arte | — |
| Pato gigante, gatos | **Manter** como cosmético | — |
| Crítico aleatório de 3% | **Substituir** por carga premiada visível | D3 |
| Sprites órfãos (`trem_loco`, `trem_wagon`, `tt`, `reach_stacker`, `rebocador`, `torre`, `containers_sheet`, `ship_cute`…) | **Apagar** os sem referência (confirmar com grep) | peso morto |
| Sondas de dev (`_dev_probe`, teclas de debug) | **Fora da build de release** (flag) | — |
| Ramos mortos da árvore (Rotas, Eventos) | **Religar** (README item 1) | D9 |
| Minijogo do labirinto | **Refazer o visual** como pátio top-down com a arte do jogo; se não ficar bom, cortar | D12 |

---

## Parte 4 — Tarefas

Formato: **ID — título** · tamanho (P/M/G) · depende de · arquivos · aceite.
Toda tarefa: testes focados passam, `tools/qa/run_all.sh` verde, captura em
320×568 e 390×844, README do subsistema atualizado, mapa de código regenerado.

### Frente A — Fundação (bloqueia o resto)

- **A1 — Nível do Terminal e portões de liberação** · G · —
  `scripts/progression/terminal_level.gd` (regras puras: XP, curva, tabela
  2.3), `feature_gate.gd` (`FeatureGate.unlocked(&"wheel")`), seção de save,
  migração (perfil antigo começa com tudo que já usou liberado).
  Aceite: suíte `level`; perfil novo no nível 1 não tem roda/missões/abas;
  save antigo não perde nada.
- **A2 — Mundo começa vazio** · M · A1
  `ground_baker.gd` (ramal só com Área Ferroviária), `port_world.gd`,
  `structure_layer.gd`: lotes baldios com placa, sem trilho/galpão/pórtico.
  Aceite: captura `fresh` sem ramal; comprar o lote faz o trilho aparecer;
  suítes `rail`, `cargo`, `gate` verdes.
- **A3 — `Fx`: biblioteca de efeitos em pool** · M · —
  `scripts/fx/fx.gd` + sprites em `gen_fx.py` (poeira, faísca, respingo, moeda,
  confete, brilho), tremor de câmera (`PortCamera.shake`), vibração
  (`Input.vibrate_handheld`, só mobile), tudo desligável por "movimento
  reduzido". Aceite: suíte `fx` (pool não cresce, nada vaza nó).
- **A4 — `AdService` + `AdPolicy` + provedor placeholder** · M · —
  Autoload, tetos e intervalos por placement (tabela 2.5), persistência diária,
  sinal `reward_granted`. Aceite: suíte `ads` (teto, intervalo, virada do dia,
  recompensa exatamente uma vez, falha do provedor não paga).
- **A5 — Dois slots de bônus e indicador no HUD** · M · —
  `GameState`: `skill_mult/time` separado de `surge`; `hud.gd`: fichas de bônus
  ativas com ícone e contagem regressiva; linha nova em `rate_breakdown.gd`.
  Aceite: gato + habilidade somam; ficha some em 0; nada sobrevive a reload.
- **A6 — Higiene e bugs da seção 1.3** · M · —
  Apagar órfãos, `tutorial.gd`, sondas de dev atrás de flag, acentos nos
  minijogos; corrigir todos os itens de 1.3 exceto tradução (R1); todo alvo de
  toque ≥ 44 px (a suíte `a11y` passa a medir isso em toda tela).
  Aceite: build menor, suítes verdes, `a11y` falha com alvo < 44.

### Frente B — Primeiros 10 minutos

- **B1 — Tutorial novo, guiado por ação** · G · A1, A2
  Espera o navio atracar antes de falar; cada passo exige a ação (tocar 5×,
  comprar Estivador, ver o TEU/s subir); voz do Seu Waldemar; câmera dá zoom
  no navio no começo. Sem "PULAR" no 1º passo; pular depois vai direto ao jogo.
  Aceite: suíte `tutorial` (não avança sem a ação, nunca aponta para alvo
  ausente), captura de cada passo.
- **B2 — Cerimônia de liberação** · M · A1, A3
  Cartão "NOVO: X" com ícone grande, brilho no botão novo até o 1º toque.
- **B3 — Objetivo único no console** · M · A1
  Uma linha "Próximo: …" com barra; substitui contrato + objetivo atuais.
  Tabela de objetivos encadeados para os primeiros 30 min.
- **B4 — Câmera** · M · —
  Pinça para zoom, toque duplo no navio enquadra o berço, zoom inicial
  enquadrando navio + cais. Aceite: suíte de câmera com eventos de toque.
- **B5 — Rebalanceio do início** · M · A1, C1
  3ª máquina em ≤5 min (README item 2); XP calibrado para a tabela 2.3;
  cenários novos no simulador (`onboarding_10m`).

### Frente C — Gameplay

- **C1 — Obras com tempo** · G · A3, A4
  `scripts/economy/build_queue.gd` (puro), persistência, visual de obra em
  `structure_layer.gd`, toque acelera, botão de anúncio, offline conclui,
  Capataz respeita fila. Aceite: suíte `build` (fila, reload no meio, offline,
  lote), simulador prova ≤15% de atraso no 1º prestígio.
- **C2 — Ritmo de Cais (combo)** · M · A3, A5
  Regras puras + medidor ao lado do navio + som que sobe de tom.
  Aceite: suíte `combo`; simulador ativo com teto de ganho ≤ +60%.
- **C3 — Carga premiada** · M · A3
  Campo no `CargoUnit` (persistido, migração), brilho no convés, ×5 ao
  descarregar. Remove o crítico de 3%. Aceite: `cargo` verde, UID preservado.
- **C4 — Habilidades do Capataz** · G · A1, A4, A5
  `scripts/economy/skill_book.gd` (puro), barra de 3 botões com recarga
  radial, nós na árvore de capital, anúncio zera recarga.
  Aceite: suíte `skills`; Prático a Bordo não cria nem perde carga.
- **C5 — Fim de escala com cerimônia** · P · A3
  Buzina, contagem do bônus, confete leve; ganho por rota explícito.
- **C6 — Conquistas que pagam + árvore de capital inteira** · M · —
  +1% por conquista (linha no detalhamento da taxa); religar Rotas/Eventos;
  "run anterior × esta" na tela de reconstrução.
- **C7 — Álbum de Navios** · M · A1
  Registro de casco × pintura × rota vistos, página por rota, prêmio por página.
- **C8 — Decisão na compra de máquina** (README item 4) · G · C1
  Cada máquina ganha um papel: gargalo real por etapa (cais → pátio → portão);
  comprar só de um tipo satura. Fazer **depois** de C1–C4 e medir.
- **C9 — Minijogos** · M · A3
  Labirinto e pilha com a arte do jogo, tela de resultado com prêmio grande,
  "jogar de novo" por anúncio, tecla Arcade (3/dia).

### Frente D — UI

- **D1 — Tipografia** · M · —
  Fonte nova 7×10 para leitura (títulos, nomes, números de preço) em
  `gen_font.py`; 5×7 só para rótulo denso. Altura mínima de texto de leitura:
  10 px lógicos. Aceite: suíte `i18n` (glifos dos 9 idiomas), `contrast`.
- **D2 — Ícones 16×16** · M · —
  Refazer `ui_icons` em 16×16 com contorno; ícone para toda aba, recurso,
  habilidade, tipo de efeito de melhoria.
- **D3 — HUD novo** · G · A5, D1, D2
  Topo: TEU grande, taxa, nível com barra de XP, fichas de bônus, engrenagem.
  Sobre o navio: **barra de progresso da escala** (DESCARGA 18/24), que hoje é
  calculada e não aparece.
  Base: 4 teclas **LOJA · MELHORIAS · ROTAS · DIÁRIO** + barra de habilidades
  acima. Lateral: roda e (quando houver) evento. Sino vira aba do Diário.
  Aceite: nada sob o dedão cobre o navio; `ui_p0`, `a11y`, `clicks` verdes.
- **D4 — Loja em 3 abas** · M · D3
  Máquinas · Terreno · Decoração. Cartão: ícone, nome, "+X/s", preço, barra de
  marco (10/25/50/100). Piada vai para o toque longo.
- **D5 — Diário unificado** · M · D3
  Hoje (objetivo, missões, sequência) · Conquistas · Álbum · Equipe · Avisos.
- **D6 — Ordens simples** · P · D3
  3 predefinições com ícone e uma linha; texto longo atrás de "?".
- **D7 — Passe de texto** · M · —
  Toda frase de UI ≤ 60 caracteres; efeito antes da piada; revisar pt-BR e en.
- **D8 — Suco de UI** · M · A3
  Número rola ao mudar, preço pisca quando fica pagável, compra solta faísca
  no cartão e no mundo, som em toda abertura/aba, transição de aba.
- **D9 — Tela de retorno (offline) e reconstrução** · P · A4
  Números grandes, "DOBRAR ▶", comparação de runs.

### Frente E — Tela inicial

- **E1 — Título novo** · M · D1, F6
  Arte-chave própria (porto ao amanhecer, navio entrando, logo grande), fundo
  com paralaxe lento e gaivotas; só **JOGAR** e engrenagem. Um toque para
  continuar o último perfil; "Trocar terminal" é secundário.
- **E2 — Seleção de terminal** · P · E1
  3 fichas com miniatura **gerada do save** (nível, TEU, dia) em vez de
  ilustração genérica.
- **E3 — Tela de carregamento e ícone/splash** · P · —

### Frente F — Gráficos

- **F1 — Chão e água** · M · — menos ruído, juntas e manchas largas, água com
  reflexo/espuma animados, borda do cais com sombra.
- **F2 — Guindastes vivos** · G · — STS e RTG: carro, cabos, spreader, luzes,
  estrutura em 3/4; animação ligada ao relay real.
- **F3 — Veículos e gente** · M · — carretas, reach stacker, empilhadeira,
  rebocador com 3/4 e sombra; estivador com mais quadros; faróis à noite.
- **F4 — Prédios restantes** · M · — torre, hub IA, portal, portão, galpão do
  ramal no padrão do armazém novo.
- **F5 — Obra, baldio e placas** · P · C1, A2
- **F6 — Peças ilustradas (pixellab)** · M · — arte do título, ícones de
  habilidade, medalhas, retratos; receita + resposta versionadas.
- **F7 — Clima e luz** · M · A3 — chuva com respingo e poça, relâmpago,
  neblina em camadas, luz de poste e janela à noite, nascer/pôr do sol.
- **F8 — Navios** · M · — 3 silhuetas desenhadas nativas (fim da escala
  0,90/1,08, que distorce pixel) mantendo as 24 baias; navio dourado.

### Frente G — Áudio

- **G1 — Sintetizador melhor** · M · — estéreo, 44,1 kHz na música, reverb de
  pente, delay, filtro 2 polos, ruído colorido (`tools/audio/synth.py`).
- **G2 — Música** · G · G1 — 6 faixas de 2–3 min (manhã, tarde, noite,
  madrugada, neblina, chuva) com 2 camadas (calma / porto cheio) cruzadas pela
  atividade; vinhetas de escala, nível, prestígio. Alternativa: encomendar ou
  licenciar trilha — decidir após ouvir G1.
- **G3 — Ambiência** · M · G1 — camas em loop: mar, zumbido do porto, chuva,
  vento; trovão e gaivota pontuais; volume próprio nos Ajustes.
- **G4 — Cobertura de SFX** · M · — todo evento mudo da auditoria: abrir/fechar
  painel, aba, sino, conquista, caminhão, cancela, carro do guindaste, fim de
  escala, início do giro, virada do dia, obra, habilidade, combo. Mínimo 3
  variações nos mais frequentes.
- **G5 — Mixagem** · P · — barramentos Música/SFX/Ambiente, ducking em
  vinheta, pool 16 + intervalo mínimo por som, pausa ao perder foco,
  desbloqueio de áudio no 1º toque (web).

### Frente R — Release

- **R1 — Tradução do conteúdo** (README item 9) · G · D7 — catálogos por
  chave, teste que falha com texto sem chave.
- **R2 — Android** · G · D3 — preset, ícones, splash, retrato travado, área
  segura, botão voltar, pausa/retomada com cálculo offline, 60 FPS em aparelho.
- **R3 — Desempenho** · M · — orçamento (≤16,6 ms p95 no cenário de estresse),
  perfil em aparelho fraco, pool de tudo que nasce por quadro.
- **R4 — Web sem threads + PWA** · M · — export sem `SharedArrayBuffer`,
  remover COOP/COEP, manifest, service worker, persistência de `user://`
  confirmada, tela de carregamento, reduzir wasm.
- **R5 — Telemetria** · M · A4 — eventos locais (funil do tutorial, tempo até
  cada nível, anúncios vistos por placement, retenção D1/D7) com provedor
  trocável; opt-in e política de privacidade.
- **R6 — Loja e jurídico** · M · — capturas, gráfico de destaque, vídeo curto,
  descrição nos 9 idiomas, classificação etária, privacidade, termos.
- **R7 — CI** · P · — destravar o Actions (orçamento) ou manter o deploy
  manual documentado como caminho oficial.

### Frente Q — Qualidade

- **Q1 — Playtest roteirizado** · M · B, C — bot que joga 30 min por toques
  reais (extensão da suíte `clicks`) e falha se ficar >60 s sem ação possível.
- **Q2 — Simulador** · M · C — cenários com obras, combo, habilidades e
  anúncios (0, 5 e 20 por dia); anúncio nunca pode valer mais que +100%.
- **Q3 — Matriz visual** · P · D — toda tela nova entra em `capture.gd`.

---

## Parte 5 — Ordem e paralelismo

Agentes em paralelo não podem editar o mesmo arquivo. Donos por onda:

| Onda | Em paralelo | Arquivos quentes (um dono por onda) |
|---|---|---|
| 0 | A1 · A3 · A4 · A6 · D1 · D2 · G1 | `main.gd` → A1; `game_state.gd` → A5 (onda 1) |
| 1 | A2 · A5 · B4 · F1 · F6 · G3 · G4 | `port_world.gd` → A2; `hud.gd` → A5 |
| 2 | B1 · B2 · B3 · C1 · C3 · F2 · G2 | `main.gd` → B1; `structure_layer.gd` → C1 |
| 3 | C2 · C4 · C5 · D3 · F3 · F4 · F5 | `hud.gd`/`command_rail.gd` → D3; `game_state.gd` → C4 |
| 4 | D4 · D5 · D6 · D8 · D9 · C6 · C9 · E1 | `shop.gd` → D4; `port_journal.gd` → D5 |
| 5 | B5 · C7 · D7 · E2 · E3 · F7 · F8 · G5 · Q1 · Q2 | `strings_ui.gd` → D7 |
| 6 | R1 · R2 · R3 · R4 · R5 | — |
| 7 | C8 · R6 · R7 · Q3 · playtest humano | — |

`strings_ui.gd` e `main.gd` são gargalo: cada agente adiciona chaves num bloco
próprio e a ligação no `main.gd` é feita por **um** agente integrador ao fim de
cada onda. Agentes não rodam o Godot em paralelo na mesma pasta (use worktrees).

Marcos:
- **M1 (ondas 0–2): "primeiros 10 minutos bons"** — perfil novo jogável e limpo.
- **M2 (ondas 3–4): "jogo divertido"** — habilidades, combo, obras, UI nova.
- **M3 (onda 5): "bonito e com som"**.
- **M4 (ondas 6–7): "pronto para loja"**.

---

## Parte 6 — Pronto para lançar quando

1. Perfil novo: em 60 s o jogador tocou, comprou e viu TEU/s subir, sem ler
   mais de 3 frases; nenhum sistema aparece antes do nível da tabela 2.3.
2. Em nenhum momento dos primeiros 30 min há mais de 60 s sem ação útil (Q1).
3. Toda ação do jogador tem som + efeito visual; todo bônus ativo tem timer.
4. Texto de leitura ≥ 10 px lógicos; alvos de toque ≥ 44 px; matriz de 7
   resoluções sem vazamento.
5. Simulador: 1º prestígio entre 60 e 90 min ativo; anúncios ≤ +100%; obras
   ≤ +15% de atraso.
6. Música ≥ 12 min sem repetir; ambiência presente; nada corta som.
7. 9 idiomas completos, com teste que impede texto sem chave.
8. Android a 60 FPS em aparelho intermediário; web sem COOP/COEP; save
   sobrevive a recarregar, fechar e ficar offline.
9. Todo placement de anúncio funciona com o placeholder, respeita teto e
   nunca é obrigatório.
10. `tools/qa/run_all.sh` verde, incluindo `clicks` e o playtest roteirizado.
