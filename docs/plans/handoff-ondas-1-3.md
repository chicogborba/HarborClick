# Handoff — ondas 0 a 3 (estado em 10/11/2026, fim da tarde)

Documento para o próximo agente continuar o HarborClick. O plano mestre é
[`plano-release.md`](plano-release.md) (Partes 1–6: diagnóstico, jogo-alvo,
cortes, tarefas por frente, ordem, definition of done). Este arquivo é o
**estado concreto**: o que já está commitado, o que ainda falta dentro das
ondas 1–3 e o que vem depois (ondas 4–7), com os arquivos donos de cada resto.

Leia antes de mexer: [`../../AGENTS.md`](../../AGENTS.md) (contratos
invioláveis de carga/save) e
[`../architecture/cargo-flow.md`](../architecture/cargo-flow.md).

---

## 1. O que está commitado (não refazer)

| Commit | Conteúdo |
|---|---|
| `6014c35` | **Onda 0**: `TerminalLevel` + `FeatureGate` (roda nível 6, missões nível 4), `Fx` em pool + tremor de câmera + vibração, `AdService`/`AdPolicy` + `PlaceholderAdProvider`, sintetizador estéreo com reverb/delay, camas de ambiência geradas, ícones 16×16 (`UiTheme.Icon16`), bugs da seção 1.3. Suítes: `level`, `fx`, `ads`. |
| `65e5ef4` | **Ondas 1–3, parte 1**: gates por nível na loja/console/ramal; slot de bônus de skill separado do surto de sorte + `BoostChips` (fichas com timer); pinça/trackpad no `PortCamera`; `TapCombo` (até ×3, faíscas, haptic, ping crescente); `SkillBook`/`SkillService`/`SkillBar` (Turno Extra, Mutirão, Prático a Bordo; recarga persistida; anúncio zera recarga); `BuildQueue` (obras com tempo por tier, 2 simultâneas, toque acelera, anúncio conclui, offline conclui, fila persistida); áudio com 16 vozes, mute no foco, 13 SFX novos ligados aos momentos mudos; tutorial de 4 passos guiado por ação. Suítes: `combo`, `skills`, `build`. |
| `0c40eed` | **Ondas 1–3, parte 2**: pontos de anúncio ligados de ponta a ponta — `wheel_spin`/`wheel_double` na roda, `minigame_retry` no fretamento perdido (janela de 6 s), `offline_double` no retorno, `build_speed` na obra; `LevelHud` (badge de nível + barra de XP + cartão de cerimônia "NOVO: X" por nível); `show_call_bonus` (confete, moedas, número dourado, haptic no fim de escala). Suíte `adflow` (todos os placements com provedor falso, anúncio recusado não paga). |
| `5af1190` | `tools/capture/capture.gd`: espera de `frame_post_draw` limitada a 1 s — janela sem foco (CI/agente) não trava mais a matriz. |
| `558918c` | **Ondas 1–3, parte 3 — A2 mundo vazio**: `GroundBaker.bake(h, rail_owned)` — corredor ferroviário só é pintado com a Área Ferroviária comprada (ou `trem` comprado, ou feature `routes`); lote vazio ganha placa de venda desenhada. Teste `ground_gate` no suite `rail`. **C3 carga premiada**: `CargoUnit.premiada` (persistido, migração default false), 1 em 12 do manifesto marcada, brilho dourado + spark no convés, paga ×5 no desembarque (base no toque + resto no pouso, cada um sob seu tx idempotente); `CRIT_CHANCE` zerado (crítico invisível substituído). Teste no suite `cargo`. **G2 música**: 6 trilhas (`music_dawn/day/dusk/night/fog/rain`) geradas e ligadas por fase/clima. **D3 barra de escala**: barra + "n/24" desenhada sobre o casco (`Ship._draw`). |

QA verde em `tools/qa/run_all.sh` (31 suítes + import + code-map) e matriz de
captura em 7 resoluções sem overlay fora do viewport.

## 2. Falta dentro das ondas 1–3 (pequeno, pode fechar já)

- **F5 — visual de obra no mundo.** Hoje a obra aparece só no `BuildHud`.
  Falta: tapume + guindaste de obra + barra de progresso **sobre o local** em
  `structure_layer.gd`/`port_world.gd`, dirigido pelo `BuildQueue` (há
  `GameState.pending` com `{id, qty, left, total}`). Dono sugerido:
  `scripts/world/`. Aceite: captura `build_site` na matriz; suite `build`
  extended com "o nó de obra existe no mundo enquanto a fila não esvazia".
- **D1 — fonte de leitura 7×10** (ficou para cá pela onda 0): gerar BMFont a
  partir da Pixelify Sans em `tools/sprites/gen_font.py`, mesmo teste de
  cobertura de glifos da suíte `i18n`. Não desenhar glifo à mão.
- **A6 resto**: X de fechar em 44 px (muda altura do cabeçalho — fazer junto de
  qualquer mudança de HUD), remover sprites órfãos e `tutorial.gd` morto
  (confirmar com grep antes), sondas de dev atrás de flag.
- **F6 — peças ilustradas (pixellab)**: arte do título, ícones de habilidade,
  medalhas, retratos no estilo top-down. **Precisa de chave de API** — a
  receita + resposta ficam versionadas em `tools/sprites/pixellab/`; o build
  nunca chama a API.

## 3. Ondas 4–7 (o plano continua valendo, em ordem)

- **Onda 4 (M2 "jogo divertido")** — D4 loja em 3 abas (`shop.gd`), D5 Diário
  unificado (`port_journal.gd`), D6 ordens simples, D8 suco de UI (número rola,
  faísca na compra, som de aba), D9 tela de retorno/reconstrução, C6 conquistas
  que pagam +1% e ramos Rotas/Eventos religados, C9 minijogos com a arte do
  jogo + tecla Arcade (3/dia por anúncio) + retry por anúncio (o retry já está
  ligado no `minigame_board.gd`), E1 título novo.
- **Onda 5 (M3 "bonito e com som")** — B5 rebalanceio do início (3ª máquina
  ≤ 5 min, cenário `onboarding_10m` no simulador), C7 álbum de navios, D7 passe
  de texto ≤ 60 chars, E2/E3, F7 clima e luz, F8 navios nativos (3 silhuetas sem
  distorcer pixel), G5 mixagem (barramentos, ducking, pool 16), Q1 playtest
  roteirizado (estender `clicks`), Q2 simulador com anúncios (anúncio nunca
  vale mais que +100%).
- **Onda 6** — R1 tradução do conteúdo (teste falha com texto sem chave), R2
  Android (precisa de aparelho real), R3 desempenho, R4 web sem threads + remover
  COOP/COEP (quebra SDKs de anúncio em iframe), R5 telemetria local opt-in.
- **Onda 7 (M4 "pronto para loja")** — C8 decisão na compra de máquina (curvas
  de custo por máquina), R6 loja/jurídico, R7 CI, Q3 matriz visual completa,
  playtest humano.

## 4. Regras de trabalho (aprendidas aqui)

- **Um Godot por pasta.** Não rodar QA/captura em paralelo no mesmo checkout
  (lock de import dá falha falsa). Para trabalho paralelo, use worktree.
- **Não editar scripts enquanto o QA/matriz roda** — o runner relê os arquivos
  entre suítes e um edit no meio vira falha falsa.
- Antes de commitar: `tools/qa/run_all.sh` verde (já inclui import + code-map
  `--check` + 31 suítes), matriz `tools/capture/capture.tscn -- matrix` sem
  overlay fora do viewport, `python3 tools/docs/generate_code_map.py` depois de
  mexer em código, README do subsistema atualizado no mesmo commit.
- Suíte nova = `tests/<nome>_test_runner.gd` + `.tscn` + entrada no
  `scenes=(...)` do `run_all.sh` + linha no `tests/README.md`. Todo runner
  precisa de roll call (ver `rail_test_runner.gd`): erro de runtime em GDScript
  não aborta o teste, então cada teste registra seu nome na última linha.
- Strings de UI só via `Loc.t("chave")` em `strings_ui.gd`, 9 idiomas, e o teste
  de `i18n` falha se faltar idioma/glifo. Texto embutido em pt-BR é dívida
  (R1, onda 6) — não piore.
- Regras puras em `RefCounted`, apresentação em `Node`. contratos de carga:
  UID antes de sprite, transferência só muda posse no `commit()`, save/reload
  preserva cada UID exatamente uma vez.
- Anúncios: só recompensado e opcional, teto diário + intervalo no `AdPolicy`,
  persistência por dia local, botão some quando o teto bate. Para ligar SDK
  real, trocar só o provedor em `scripts/monetization/`.

## 5. QA rápido

```bash
tools/qa/run_all.sh                                            # tudo
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/cargo_test_runner.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path . tools/capture/capture.tscn -- matrix
/Applications/Godot.app/Contents/MacOS/Godot --path . tools/capture/capture.tscn -- 390x844 shop
python3 tools/balance/run_balance.gd --help 2>/dev/null || true # simulador (tools/balance/run_balance.gd)
```

## 6. Idéias do template externo (donchitos/claude-code-game-studios)

O `#engines` do template confirma a escolha: Godot 4 com GDScript, código em
`src/`-equivalente (aqui, `scripts/`), testes com root próprio (`tests/`). Os
padrões de workflow que valem importar para cá:

- **Checkpoint por feature**: cada tarefaaceita vira um commit pequeno e
  reverter é barato — já é a prática aqui (ver histórico).
- **Playtest semeado depois de cada feature**: é o `.devprobe` + a suíte
  `clicks` (bot que joga com toques reais). Q1 (onda 5) formaliza isso.
- **Handover card por entrega**: este documento. Depois de cada onda, atualizar
  a seção 1 (commits) e a seção 2 (restos).
- **Brief de uma página por onda**: a tabela da mensagem original (onda → foco
  → marco) funciona como brief; manter a tabela do README raiz apontando para
  este plano.
