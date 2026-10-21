# G✦A✦U RPG — plataforma digital v0.2

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

- `index.html` — aplicativo completo (livro pesquisável, criador em 10 etapas, grimório e ficha automática), versão 0.2
- `livro-regras.pdf` — livro completo revisado em 38 capítulos (450 registros úteis e 410 entradas no grimório), edição 0.2
- `ficha-preenchivel.pdf` — ficha PDF editável em 6 páginas (incluindo Conjuração e Grimório), versão 0.2
- `.nojekyll` — evita transformação por Jekyll

## Edição ilustrada (branch `edicao-ilustrada-teste`) — 21/10/2026

Branch de teste com diagramação de editora, sem alterar nenhuma regra, valor ou estrutura de dados do sistema.

### Direção de arte

Referências: **Tormenta 20** (capitulares, cartões de magia em duas colunas, faixas cromáticas por parte), **Feiticeiros & Maldições** (cartões de talento com energia violeta/carmesim, selos de pré-requisito) e **Ordem Paranormal** (dossiês de perícia e investigação em âmbar/vermelho, quadro de pistas e evidências).

### Tipografia (4 famílias embutidas no próprio arquivo)

| Família | Uso |
| --- | --- |
| **Cinzel** (700/900) | títulos de capa, capítulos e destaques solenes |
| **Oswald** (500/700) | navegação, botões, rótulos, cabeçalhos de tabela |
| **Crimson Pro** (400/400 itálico/600) | corpo de texto, legendas e descrições |
| **Special Elite** (400) | carimbos de fonte canônica, selos e notas de registro |

Todas são embutidas como WOFF2 em `index.html` — a plataforma continua funcionando **offline**, sem CDN.

### Ilustrações

- **42 imagens** em `assets/art/` (capa, aberturas de parte, retratos individuais das **7 raças** e das **11 classes**, vinhetas temáticas de combate, investigação, talentos, modelos e grimório).
- Também embutidas em `index.html` como URIs de dados (otimizadas para ~2,2 MB), garantindo leitura ilustrada mesmo dentro de iframes isolados.
- **113 imagens** distribuídas pelo `livro-regras.pdf`, integradas ao texto e às tabelas (figuras entre blocos de regras, retratos ao lado de cada raça e classe).

### `livro-regras.pdf` (226 páginas)

- Capa **sangrada** (A4, moldura ornamental, contadores de sistema).
- **Sumário visual cromático** em 2 páginas com as 7 partes e os 38 capítulos.
- **7 aberturas de parte** em página inteira (fundo ilustrado, moldura, selo e lista de capítulos).
- Cada capítulo com **faixa ilustrada**, selo de fonte canônica e corpo em **2 colunas**; tabelas e figuras com `column-span: all`.
- Cartões de **magia/prece** (faixa de nível, grade de execução/alcance/duração/resistência), cartões de **talento** (selo de pré-requisito), **dossiês de perícia**, **selo de ND** nos modelos, caixas de **traços raciais em pergaminho**.
- Marcadores (bookmarks) nativos: capa, sumário, 7 partes e 38 capítulos; **fita de borda colorida** e rodapé cerimonial com numeração.

### Plataforma `index.html`

- Herói da tela inicial com a arte de capa; cartões de entrada ilustrados.
- Livro com **banner de capítulo ilustrado**, cartões por registro com faixa colorida por parte, **figuras integradas ao longo dos capítulos** e **diagramação em 2 colunas** em telas largas.
- Criador com **galeria de retratos das 11 classes** (seleção por clique na arte) e **retratos nas 7 raças**.
- Ficha com **faixa ilustrada** do personagem (retrato da classe).
- Mantém a responsividade: nenhuma rolagem horizontal em 390 px de largura.

### `ficha-preenchivel.pdf`

Ficha editável em 6 páginas com **faixas ilustradas por página**, bordas douradas, selo do grimório na página de feitiços e todos os 160 campos AcroForm preservados.

## Conferência e inclusão do Grimório (Discord → Livro, Criador e Ficha) — 21/10/2026

Foram conferidos todos os canais e tópicos do servidor `𝗚✦𝗔✦𝗨 | 𝐑𝐏𝐆` na categoria `‼️┊SISTEMA`: **8 canais** e **30 tópicos ativos** (`38` fontes no total). As `28` marcações vazias anteriores em `feitiços` e o cabeçalho provisório `Lista de Magias Universais` foram substituídos na origem pelos índices atualizados de Magias Arcanas e Magias Divinas e por **11 novos tópicos de magias**:

- `Truques` (`6` mensagens · `23` entradas)
- `Magias Arcanas de 1° Nível` (`15` mensagens · `45` entradas)
- `Magias Arcanas de 2° Nível` (`20` mensagens · `65` entradas)
- `Magias Arcanas de 3° Nível` (`18` mensagens · `51` entradas)
- `Magias Arcanas de 4° Nível` (`20` mensagens · `53` entradas)
- `Magias Arcanas de 5° Nível` (`25` mensagens · `50` entradas)
- `Magias Arcanas de 6° Nível` (`15` mensagens · `36` entradas)
- `Magias Arcanas de 7° Nível` (`11` mensagens · `24` entradas)
- `Magias Arcanas de 8° Nível` (`14` mensagens · `27` entradas)
- `Magias Arcanas de 9° Nível` (`14` mensagens · `24` entradas)
- `Preces` (`3` mensagens · `12` entradas)

Totais consolidados na publicação:

- **38 capítulos** (`8` canais e `30` tópicos ativos)
- **450 registros úteis** (`443` textuais e `7` registros de anexos; os `65` marcadores compostos apenas por pontos em `perícias` [18] e `outras-mecânicas` [47] permanecem excluídos)
- **1.289 entradas únicas** no índice alfabético e no grafo de referências cruzadas, preservando variantes homônimas e unindo integralmente as 6 magias longas divididas entre mensagens (`Recipiente Arcano`, `Símbolo da Dor`, `Prisão`, `Desejo`, `Esfera Prismática` e `Portal`)
- **410 entradas catalogadas no Grimório** (`406` arcanas e `122` com acesso divino explícito), integradas com busca e filtros no **Criador (Etapa VIII)**, gestão direta na **Ficha Automática** e página dedicada **Grimório — Feitiços e Preces** na **Ficha PDF Preenchível (6 páginas)**

Lacunas que permanecem pendentes na origem oficial: tópicos exclusivos de `Magias Divinas de 1° a 9° Nível`, equipamentos e preços, sistema completo de combate, origens/antecedentes, experiência geral, divindades consolidadas, 3 classes restantes e 10 raças restantes. Nenhuma credencial, dado de autor ou exportação bruta do Discord integra o repositório.

## Conferência direta de Sistema — 19/10/2026

Foram consultados 8 canais e 19 tópicos ativos, totalizando 383 mensagens. O capítulo de magia foi incorporado com cálculos de PM base por classe e CD a partir de modificador de conjuração confirmado separadamente, preservando a divergência entre o capítulo geral de magia (4 magias iniciais de nível 0) e a classe Mago (5 magias iniciais de nível 0).

## Limpeza editorial — 19/10/2026

Foram removidos os marcadores compostos somente por pontos, revisada a ortografia, normalizadas ligaduras tipográficas e formatadas tabelas legíveis sem alterar números, fórmulas, custos ou efeitos das regras.
