# G✦A✦U RPG — plataforma digital v0.4

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

- `index.html` — aplicativo completo (livro pesquisável, criador em 10 etapas, grimório e ficha automática), versão 0.4
- `livro-regras.pdf` — livro completo revisado em 44 capítulos (1.464 registros úteis e 525 entradas no grimório), edição 0.3 — **não regenerado nesta rodada**; o HTML está na edição 0.4
- `ficha-preenchivel.pdf` — ficha PDF editável em 6 páginas (incluindo Conjuração e Grimório), versão 0.2
- `.nojekyll` — evita transformação por Jekyll

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
