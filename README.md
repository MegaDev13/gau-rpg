# G✦A✦U RPG — plataforma digital v0.5

Plataforma offline/online com livro pesquisável, criador de personagens, grimório catalogado e ficha automatizada. **Edição preliminar:** partes das regras ainda aguardam publicação no servidor oficial.

## Como publicar no GitHub Pages

1. Crie um repositório público chamado `gau-rpg` na conta `MegaDev13` (ou escolha outro nome).
2. Envie **os arquivos desta pasta diretamente para a raiz do repositório**; não envie somente o `.zip`.
3. Abra **Settings → Pages → Build and deployment → Source: Deploy from a branch**.
4. Selecione **Branch: main**, pasta **/(root)**, e **Save**.
5. Caso use o nome sugerido, o endereço padrão será `https://megadev13.github.io/gau-rpg/` (disponível apenas após a publicação efetiva).

`index.html` contém todo o JavaScript e as regras necessárias; não há servidor nem instalação de dependências. Arquivos PDF são disponibilizados como links na tela inicial.

## Aviso de conteúdo

O compêndio foi derivado de exportações do Discord e pode incluir textos de RPGs de terceiros, referências a mensagens e links para anexos do Discord. Antes de tornar o repositório público, revise direitos de publicação e quais informações deseja divulgar. Nenhuma licença de redistribuição foi presumida. Os arquivos brutos de mensagens não foram incluídos neste pacote de publicação.

## Arquivos

- `index.html` — aplicativo completo (livro pesquisável, criador em 10 etapas, grimório e ficha automática), versão 0.5
- `livro-regras.pdf` — livro completo revisado em 44 capítulos (1.464 registros úteis e 525 entradas no grimório), edição 0.3 — **não regenerado nesta rodada**; o HTML está na edição 0.4
- `ficha-preenchivel.pdf` — ficha PDF editável em 6 páginas (incluindo Conjuração e Grimório), versão 0.2
- `.nojekyll` — evita transformação por Jekyll

## Atualização do servidor — 26/10/2026 (v0.5)

Terceira varredura sobre a edição 0.4. O servidor mexeu em quatro canais: dois ganharam seções novas de regra, um ganhou arte e um recebeu correções pontuais.

| Item | Antes | Depois |
|---|---|---|
| Fontes (canais + tópicos) | 50 | 50 |
| Mensagens com conteúdo | 581 | **594** |
| Registros (entradas) | 1.617 | **1.635** |
| Magias catalogadas | 642 | 642 |
| Ilustrações embutidas | 0 | **7** |

**Conteúdo novo:**

- `#「📕」perícias` — **4 mensagens · 9 entradas**: como funcionam as graduações e o teste de perícia (`1d20 + graduações + modificador de habilidade + BBA`), perícias que exigem treinamento, penalidade de armadura, novas tentativas, condições favoráveis e desfavoráveis e testes opostos, com a tabela de classes de dificuldade de 0 a 40.
- `#「📕」outras-mecânicas` — **2 mensagens · 9 entradas**: **Tendências** — o eixo ético (bondade, neutralidade, maldade) e o eixo moral (lealdade, neutralidade, caos).
- `#「📕」raças` — **7 ilustrações** (um casal de cada raça, publicadas em 15/10) embutidas no capítulo **II — Povos**, uma imediatamente antes do bloco da sua raça.

**Editadas na origem (6 mensagens re-sincronizadas):** *Humanos* (Valkaria → **Tzeki**), *Determinação e Resiliência* (Arton → “o continente”), *Jogatina* (swashbucklers → pistoleiros), *Jogo de Azar* (menção de canal), *Pergaminhos* (TO → **PO** nas nove linhas da tabela de preços) e *Cura* (dano não letal).

**Descartado:** 67 mensagens com apenas `.` (45 em `outras-mecânicas`, 22 em `combate`) — marcadores vazios, não são regra.

**Correções editoriais (2):** a edição feita no servidor quebrou duas frases e elas foram restauradas — “o sonho secreto incutido **nos continentes** em seus corações” voltou a citar **Tzeki**, e a regra de morte de *Dano Não-Letal*, sobrescrita por “-1 à -13”, voltou à redação do restante do capítulo (“metade dos PV totais”).

**Observação para a próxima rodada:** o servidor começou o reskin do cenário — Valkaria já virou Tzeki e Arton virou “o continente” em `raças`; os demais canais (magias, talentos, Poderes Concedidos) continuam com os nomes canônicos de Arton.

## Atualização do servidor — 22/10/2026 (v0.4)

Segunda varredura do servidor `𝗚✦𝗔✦𝗨 | 𝐑𝐏𝐆` sobre a edição 0.3. O conteúdo novo estava nos dois pontos que a versão anterior listava como pendentes.

| Item | Antes | Depois |
|---|---|---|
| Fontes (canais + tópicos) | 44 | **50** |
| Mensagens com conteúdo | 501 | **581** |
| Registros (entradas) | 1.464 | **1.617** |
| Magias catalogadas | 525 | **642** |
| Talentos | 494 | 494 |

**Conteúdo novo incluído:**

- `#「📕」combate` — **25 mensagens · 32 entradas**: como funciona o combate, jogada de ataque, acertos e erros automáticos, dano, acertos críticos, CA, PV, testes de resistência, iniciativa, a rodada, tipos de ação (padrão, movimento, completa, livre, reação), ferimentos e morte, cura, dano não letal, movimentação, condições especiais (com as duas tabelas de modificadores), seres maiores ou menores, quebrando objetos (tabelas de objetos e de armas/armaduras/escudos) e combate montado.
- `Magias Divinas de 5° a 9° Nível` — **55 mensagens · 117 magias**: o grimório divino agora vai de 1º a 9º nível, como o arcano.

**Atualizações em conteúdo existente:** 11 mensagens editadas na origem foram re-sincronizadas (duas listas de magias em `feitiços` e nove tópicos de `magia`); as menções a canais passaram a usar o nome do tópico em vez do identificador.

**Pendências restantes:** tabela de preços detalhada, origens, progressão/XP, divindades e cultos, 3 classes e 10 raças.
