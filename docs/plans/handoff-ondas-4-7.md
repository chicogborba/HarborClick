# Handoff — ondas 4 a 7 (estado em 10/11/2026, noite)

Complemento do [`handoff-ondas-1-3.md`](handoff-ondas-1-3.md). Plano mestre:
[`plano-release.md`](plano-release.md). Estado por commit no git (`14ca1fe` a
`85b2fcb` + docs).

## O que entrou (ondas 4–7)

- **Onda 4 (M2)**: conquistas pagam +1% permanente cada (`GameState.ACHIEVEMENT_BONUS_PER`,
  linha "Conquistas" no `rate_breakdown`); ramos Rotas/Eventos da árvore de
  capital vivos (`route_reward_multiplier` no frete, `route_slots` rotaciona as
  top-N rotas, `event_reward_multiplier`/`event_duration_multiplier` nos
  charters; gate por nível em vez de botão morto). Título limpo — marquee é só
  JOGAR/CONTINUAR/AJUSTES, links em Sobre. Tecla ARCADE no Diário
  (`minigame_play`, 3/dia, prêmio lump pequeno, sem stake; adflow cobre o cap).
  Pulso no preço quando o card fica comprável. Diálogo de prestígio mostra
  "run anterior × esta".
- **Onda 5 (M3)**: 3 cascos nativos a 1:1 (`ship_top_feeder/panamax/new_panamax`,
  mesmo canvas 66×232 e as mesmas 24 baias — acabou a escala 0.90/1.08 que
  distorcia pixel). ÁLBUM de navios no Diário (chip por livery; página completa
  paga 300 s de renda, uma vez). Raio visual na chuva + trovão; janelas quentes
  nos prédios à noite (`StructureActor._window_light`). 6 trilhas de música por
  clima/hora.
- **Onda 6**: preset Web sem threads + PWA ligado (ícones gerados por
  `tools/sprites/gen_icons.py`, retrato, offline page) e **COOP/COEP removidos**
  do Traefik/serve_web — desbloqueia SDK de anúncio em iframe na web (R4).
  Telemetria local opt-in (default OFF, toggle em Ajustes com texto de
  privacidade; eventos: tutorial, nível, ads por placement, sessão; espelho
  `user://telemetry.jsonl` limitado a 2000 linhas; provedor trocável em
  `scripts/telemetry/`). Preset Android criado (retrato, gl_compatibility,
  ícones adaptativos). Perf: `perf.tscn` PASS (p95 6,94 ms ≤ 16,67 ms).
- **Onda 7**: **C8** — cada máquina tem seu próprio `growth` (1.14–1.20; as duas
  primeiras mantêm 1.15 para preservar os primeiros 10 min), loja e simulador
 foram atualizados para ler; planos do simulador ganharam `cheap_bias`/`big_bias`.
  R6: [`docs/store-listing.md`](../store-listing.md) (título, short/long em 9
  idiomas, privacidade, termos, classificação). R7: CI existe
  (`.github/workflows/deploy-production.yml`), validado estaticamente.

## O que ainda falta (honesto)

1. **R1 — traduzir o conteúdo dos catálogos** (structure_db, upgrade_db,
   achievement_db, land_db, port_journal, npc, minijogos) para as 9 línguas via
   chaves + teste que falha com texto sem chave. É o maior débito restante.
2. **F5** — visual de obra no mundo (tapume + guindaste + barra sobre o local),
   dirigido pelo `BuildQueue`.
3. **D1** — fonte de leitura 7×10 a partir da Pixelify Sans (`gen_font.py`).
4. **F6** — artes pixellab (título, ícones de skill, medalhas) — precisa de
   chave de API; receita + resposta versionadas.
5. **Aparelho Android real** — 60 FPS, pause/resume, área segura (onda 6
   dependia disso; preset existe, falta rodar).
6. **Playtest humano** + gráfico de destaque/vídeo pra loja (as capturas da
   matriz em `user://uishots/` já servem de base).
7. **Ligar ads reais** — trocar `PlaceholderAdProvider` por `AdMobProvider`/
   `H5AdsProvider` em `scripts/monetization/`; a web já está sem COOP/COEP.

## Regras que continues valendo

Mesmas do handoff anterior: um Godot por pasta (worktree pra paralelo), QA
verde antes de commit (`tools/qa/run_all.sh` = 32 suítes + import + code-map),
matriz `capture.tscn -- matrix`, code-map regenerado, README do subsistema no
mesmo commit, `git add` com caminhos explícitos (NUNCA `git add -A` cego — uma
pasta `salarios/` alheia quase foi embarcada; está no `.gitignore` agora),
runners com roll call, `Loc.t` pra todo texto de UI, contratos de carga
(UID, commit, save) intocáveis.
