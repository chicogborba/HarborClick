# Princípios de clicker aplicados ao HarborClick

Destilado da pesquisa de gênero (GDC/Kongregate sobre matemática de idle games,
os pós-mortems de *Clicker Heroes 2*, *War Clicks* e *RuneScape: Idle Adventures*,
e a leitura de *Cookie Clicker*, *AdVenture Capitalist*, *Realm Grinder* e
*Egg, Inc.*) e traduzido para as decisões que este repositório de fato toma.

Este documento é curto de propósito. Ele responde **"isso está bom?"**; o
[README](../../README.md) responde **"o que falta?"**.

---

## As dez regras

### 1. O clique inicia a fantasia; ele não aprisiona ninguém

O toque existe para ensinar a relação ação → recurso e para dar agência na
espera. Quando a economia chega a escalas que a mão humana não acompanha, o
toque deve virar *empurrão* — acelerar, escolher, ativar — e nunca obrigação.

> **No HarborClick:** o toque no navio move uma caixa; portêiner, transtêiner e
> guindaste flutuante fazem a mesma transação sozinhos. Uma escala inteira roda
> sem um toque quando há equipamento. ✅

### 2. Toda espera tem contexto

O jogador precisa saber **o que** está esperando, **quanto falta**, **como
acelerar** e **qual decisão** virá depois. O problema não é o intervalo longo; é
o *stall não informado*, em que o tempo até a próxima decisão cresce sem meta
visível.

> **No HarborClick:** o chip do berço diz `DESCARGA 18/24`; o objetivo fixado no
> rail diz o que vem depois. ⚠️ Falta a estimativa de tempo até a próxima compra
> possível — o "faltam ~2 min" que transforma espera em previsão.

### 3. Comprar precisa mudar alguma coisa que se vê

Este é o pecado mais comum e mais letal do gênero: a compra altera um número num
painel que está cobrindo a tela e nada mais. Uma compra tem que ter **corpo**.

> **No HarborClick:** cada compra faz a máquina correspondente sacudir nas molas
> e solta um `+X TEU/s` sobre ela no pátio; a taxa no contador anuncia o ganho em
> porcentagem. Compras acima do teto visual de uma máquina caem sobre uma que já
> existe, então dinheiro gasto sempre tem onde aterrissar. Cada melhoria acende
> um farol âmbar na máquina que ela melhorou. ✅
>
> Ver `StructureLayer._announce`, `Readout._on_cps` e
> `StructureActor.refresh_upgrade_marks`.

### 4. Números explicam relações, não só magnitude

`+25%` de uma base que o jogador não conhece é superstição, não estratégia. A
comparação entre duas compras precisa de uma métrica comum, e a melhor é o
**tempo de retorno**:

```
payback = custo total da compra ÷ ganho de produção por segundo
```

> **No HarborClick:** o cartão da loja mostra `+X TEU/s • paga em 4min` assim que
> a máquina é acessível — antes disso ela ainda está sendo *descoberta* e o card
> mantém a piada. ✅ ⚠️ Falta o painel de decomposição (base × upgrade ×
> prestígio × evento) para quando os multiplicadores empilham.

### 5. Automação eleva o nível da decisão; não retira o jogo

Ao automatizar uma tarefa, abra uma decisão de ordem superior: prioridade,
configuração, alocação, build. Automação que executa tudo perfeitamente elimina
escolhas; automação deliberadamente incompetente vende conveniência.

> **No HarborClick:** ✅ ⚠️ parcialmente. `CraneAllocation` fez da gangue um
> recurso único a ser dividido: com mais de um berço trabalhando o jogador dá a
> ordem permanente — dividir por igual, mandar tudo para quem está mais perto de
> zarpar, ou para o maior casco. Antes disso cada berço recebia a taxa inteira
> do porto sozinho, então automatizar não abria pergunta nenhuma; era o sintoma
> exato desta regra, escondido atrás de um número.
>
> `Foreman` fez o mesmo com o dinheiro: depois da primeira reconstrução o porto
> compra sozinho, e o que o jogador escolhe é *o que ele otimiza* e *quanto do
> caixa ele nunca pode encostar*. A reserva é o desenho — sem ela a automação de
> compra apaga o jogo em vez de elevá-lo, porque a carteira fica no zero e nada
> que exija poupar volta a ser alcançável.
>
> Ainda falta a terceira: **política de pátio** (estoque contra giro).

### 6. A logística tem que ser real, não decorativa

Um contêiner precisa ter identidade, origem, destino e **uma cadeia de custódia
visível**. Máquinas que animam num timer são cenário; máquinas que se passam a
carga umas para as outras são o jogo.

> **No HarborClick:** `CargoUnit` tem UID persistente e cada transferência é uma
> transação com reserva, commit e rollback. Desde o `CargoRelay`, o percurso é
> uma cadeia: o portêiner tira do costado e põe no apron, o cavalo mecânico
> dirige até a faixa do bloco, o transtêiner levanta da carreta e empilha. ✅
>
> Com o pátio vazio de equipamento a caixa atravessa sozinha — e **comprar o
> primeiro cavalo mecânico é o momento em que o porto começa a dirigir carga**.

### 7. Todo reset abre um futuro

Prestígio sem escolha nova é repetição comprimida. O reset precisa responder,
antes de acontecer: o que se perde, o que fica, quanto se ganha, quanto tempo
para recuperar, e **que conteúdo novo abre**.

> **No HarborClick:** o diálogo de prestígio mostra o ganho e a árvore de
> capital, e desde o `Foreman` a primeira reconstrução **abre alguma coisa**: o
> capataz, que é exatamente a dor que o segundo run tinha — refazer trinta
> compras que o jogador já sabe de cor. ⚠️ Ainda falta a estimativa "você
> recupera este ponto em ~N minutos".

### 8. Confiabilidade antes de infinito

Save atômico, migração, progresso offline, números grandes e observabilidade são
*features centrais*, não infraestrutura. O pós-mortem de *War Clicks* perdeu mais
de 100 mil jogadores para bugs de lançamento; nenhum design compensa isso.

> **No HarborClick:** save v3 por perfil com escrita temporária, backup, rotação,
> migração e reconciliação de transferências em voo; 20 suítes headless. ✅

### 9. Nada pode travar

Um jogo idle é uma máquina de estado que roda sozinha. Toda decisão de
apresentação precisa de um caminho de fuga: se a animação bonita não puder
acontecer, a transação acontece mesmo assim.

> **No HarborClick:** é o contrato explícito do `CargoRelay`. Um cavalo mecânico
> que não aparece em 3 s, que trava 22 s, ou que é liberado no meio da viagem
> devolve a caixa para o arco simples. `tests/relay_test_runner.gd` prova os três
> casos, mais uma escala inteira ponta a ponta. ✅

### 10. Profundidade se revela; não se despeja

A primeira tela é simples; o jogo completo não precisa ser. *Cookie Clicker*
começa com um botão e termina em ascensões, minigames e lore.

> **No HarborClick:** loja com teaser da próxima máquina, rotas, contratos,
> tripulação com dossiê, escalas especiais. ✅ ⚠️ A curva de *novidade* ainda não
> foi medida contra as metas de progressão do README.

---

## Os cinco erros que matam um clicker

| Erro | Sintoma no jogador | Sinal antecipado na telemetria |
|---|---|---|
| Crescimento sem decisão | "só clico e compro o mais barato" | uma compra domina >80% das escolhas |
| Espera sem meta | "abri e não tinha nada pra fazer" | tempo até a próxima decisão cresce sem salto de satisfação |
| Automação que apaga o jogo | "não preciso mais abrir" | ações significativas por minuto caem após o desbloqueio |
| Reset que parece punição | "prestigiei e desisti" | preview aberto, reset não concluído; churn logo após o reset |
| Compra invisível | "comprei e não aconteceu nada" | tempo na loja alto, retenção D1 baixa |

O quinto é o que este projeto acabou de atacar de frente.

---

## Checklist de aceite para qualquer feature nova

Antes de marcar qualquer item como pronto:

1. **Vê-se?** A mudança tem corpo no porto ou apenas no painel?
2. **Lê-se?** O jogador consegue dizer *por que* a produção subiu?
3. **Decide-se?** A feature abriu uma escolha ou só um número maior?
4. **Trava?** Existe caminho de fuga se a apresentação falhar?
5. **Persiste?** Snapshot, restore, novo perfil, migração e regressão de reload.
6. **Cabe?** Passa na matriz de captura em todas as resoluções.
7. **Alcança?** Foco por teclado, contraste AA, opção de reduzir movimento.
8. **Prova-se?** Tem teste que falharia se a feature fosse removida.

Os itens 1 a 3 são novos, e são exatamente o que faltava: o repositório já era
rigoroso em 4–8 e permissivo em "isso muda alguma coisa que dá pra ver?".

---

## Métricas que este jogo deveria medir

Não há telemetria no HarborClick e, por ser single-player offline, ela não é
obrigatória. Mas o **simulador de balanceamento**
(`tools/balance/run_balance.gd`) pode responder às mesmas perguntas sem coletar
nada de ninguém:

| Pergunta | O que simular |
|---|---|
| O início prende? | tempo até primeira compra, primeira automação, primeiro marco |
| Existe escolha real? | quantas compras diferentes um agente guloso versus um poupador faz |
| Onde está o muro? | tempo entre decisões ao longo da run, procurando o salto |
| O prestígio compensa? | tempo de recuperação do pico anterior após o reset |
| A build errada condena? | run de um agente que compra sempre a opção pior |
| O casual chega lá? | sessões curtas + offline com cap de 8 h a 50% |

Rodar isso é barato e é a única forma honesta de dizer que a curva está boa.

---

## Fontes

Resumo em `docs/design/` porque decisões de produto vivem perto do código que
elas governam. As referências completas — GDC "Quest for Progress", pós-mortems
de Playsaurus/Hyper Hippo/Jagex, WCAG para movimento e contraste — estão na
pesquisa que originou este documento e não são reproduzidas aqui.
