# S.I.G.E.A — Máscaras · Livro de Regras (branch `sigea-livro`)

Livro completo em HTML do RPG do servidor **S.I.G.E.A — Máscaras** (Discord), construído no mesmo molde do projeto GAU: documento único, busca, navegação lateral e **ficha automática**.

O arquivo é **`index.html`** nesta branch — abre direto no navegador, sem servidor e sem internet (todas as imagens vão embutidas em base64).

## O que tem dentro

| # | Capítulo | Conteúdo |
|---|----------|----------|
| 01 | Depois do C.R.E.P. | Mundo em 3048, meta-humanos desde 2030, Nova Vera Cruz, Avalon, Khalamit |
| 02 | A S.I.G.E.A. | A escola, doutrina, rotina, instalações, hierarquia, Black Guard |
| 03 | Restrição de Poderes | Regras da casa transcritas + **auditoria dos 59 canais** |
| 04 | Como Se Joga | Mecânica básica, graus de sucesso, medidas, rodada, condições, PH, dano |
| 05 | Criando um Cadete | NP/PP (15 × NP), limites, nove passos, arquétipos, complicações |
| 06 | Habilidades & Defesas | 8 habilidades e 5 defesas |
| 07 | Perícias | 16 perícias com usos e avaliação escolar |
| 08 | Vantagens | 67 vantagens completas com tipo e graduações |
| 09 | Poderes | 61 efeitos (tabela de custos), 35 extras, 21 falhas, descritores |
| 10 | Equipamento | Armas, armaduras, escudos, veículos, quartel-general |
| 11 | Combate | Ataques, manobras, área/multiataque/crítico, recuperação |
| 12 | Mestrando | Motores de campanha, capítulos das temporadas 1–2, vilões |
| 13 | Elenco | 55 NPCs (Vanguarda, docentes, 1º/2º/3º ano, Black Guard, Guren) + party |
| 14 | Conquistas | Treinamento, relacionamento, faíscas, clubes, estágios, pets, casal |
| 15 | Ficha Automática | Calculadora de PP, validação de NP, dado, salvar/exportar/imprimir |
| **A** | Heróis Adolescentes | Apêndice opcional a partir do *Hero High*: NP por era, benchmarks teen, perícias, vantagens, 13 arquétipos, escola como cenário |
| **B** | Linha do Tempo | Temporadas 1–2, calendário de mesa (2026), progressão da party e lacunas do registro |
| 16 | Licença | Créditos e OGL 1.0a |

## Ficha automática

- Orçamento **15 × NP** com **ajuste SIGEA de –6** (regra do Mestre publicada em `#regras`).
- Soma habilidades (2 PP), defesas (1 PP), perícias (0,5 PP), vantagens (1 PP) e poderes `((base + extras − falhas) × graduação) + fixos`.
- Valida limites do NP (defesas, Resistência, 2×NP, graduação de efeito).
- Salva em `localStorage`, exporta/importa `.json`, imprime.
- Dado flutuante com d20 + modificador.

## Fontes

- **Cenário, elenco, campanha e regras da casa:** servidor *S.I.G.E.A — Máscaras* — canais `#história`, `#escola`, `#regras`, `#cápitulos`, `#corpo-docente-e-profissionais`, `#turma-do-primeiro/segundo/terceiro-ano`, `#black-guard`, `#guren`, `#vanguarda`, `#conquistas` e fichas.
- **Sistema mecânico:** *Mutantes & Malfeitores 3ª Edição* (Green Ronin Publishing), Open Game Content sob **OGL 1.0a**. Custos, tabelas e terminologia conferidos na edição em português disponibilizada pelo próprio servidor no canal `#drive`.
- **Apêndice A:** *Hero High* (Green Ronin), suplemento de M&amp;M 3ª Edição — fonte direta das regras **Holding Back** e **Exemplos de Complicações** já publicadas em `#regras`. Material de referência, não Open Game Content além da OGL.
- **Apêndice B:** reconstruído dos canais `#cápitulos`, `#conquistas`, `#rolagens`, `#rolagens-vilões` e do calendário de publicação das mensagens.
- **Imagens:** materiais publicados pelos membros do servidor.

## Auditoria de restrição de poderes

Varredura de **9.428 mensagens em 59 canais**: a normativa está concentrada em `#regras` (7 ocorrências) — Limitações de Poderes (movimentação, Nulificar, Imortalidade, Regeneração), Holding Back, Complicações, ajuste de criação e Filler. Os outros 5 canais com ocorrências são ruído (conversa, citações, biografia). Detalhamento no capítulo 03.

## Licença

Conteúdo mecânico derivado de material Open Game Content, publicado sob a **Open Game License 1.0a** (texto completo no capítulo 16). Nomes, cenário e personagens do S.I.G.E.A permanecem *Product Identity* de seus autores. Material de fã, sem fins comerciais.

> A branch `main` continua com o livro do GAU, intacta. Este livro vive apenas em `sigea-livro`.
