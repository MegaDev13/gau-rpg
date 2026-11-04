# Veyrath 0.12 · Implementação do dossiê

Branch `feature/rpg-narrativo-mundo-vivo`. Base `91fa65d98ed448ae99593fd2bdcc7d7b5583f7d0` (0.11). Versão Android `0.12.0`, versionCode `12`.

Em **Crônicas → Sagas e conflitos do dossiê**, os acontecimentos aparecem no local quando seus gatilhos são encontrados. Prazos de histórias já abertas avançam mesmo longe do jogador. Cada decisão implementada informa custo, impedimento e resultado. Os arquivos de conteúdo mantêm o texto autoral separado das regras executáveis.

## Situações

| ID | Família | Situação | Estado |
|---|---|---|---|
| S01 | F01 | As quatro portas da casa do ferro | Pendente de regras · texto importado |
| S02 | F01 | Uma carta para quem não nasceu aqui | Pendente de regras · texto importado |
| S03 | F01 | O inventário das coisas que não se vendem | Parcial jogável · opções A |
| S04 | F02 | A promessa à beira do trilho | Parcial jogável · opções A, B, D |
| S05 | F02 | Duas mesas, uma casa | Parcial jogável · opções A, C |
| S06 | F02 | O anel que não compra uma aliança | Parcial jogável · opções A, B, D |
| S07 | F03 | O trono que não sabe esperar | Pendente de regras · texto importado |
| S08 | F03 | A lei que mudou de pai | Pendente de regras · texto importado |
| S09 | F03 | O ministro que vendia silêncio | Pendente de regras · texto importado |
| S10 | F04 | A greve dos sinos calados | Pendente de regras · texto importado |
| S11 | F04 | O pão que não cruzou a ponte | Parcial jogável · opções A, B, C, D |
| S12 | F04 | A sociedade dos três fornos | Parcial jogável · opções A, B, D |
| S13 | F05 | O hospital de luz fria | Parcial jogável · opções A, C, D |
| S14 | F05 | O experimento sem testemunha | Parcial jogável · opções A, B, D |
| S15 | F05 | O vapor da última estação | Pendente de regras · texto importado |
| S16 | F06 | O ninho sob o relógio | Parcial jogável · opções A, D |
| S17 | F06 | O nome que o dragão não concedeu | Parcial jogável · opções A, B, D |
| S18 | F06 | As escamas no rio negro | Parcial jogável · opções A, B, D |
| S19 | F07 | A testemunha que mudou a chuva | Pendente de regras · texto importado |
| S20 | F07 | A imprensa dos cinco nomes | Parcial jogável · opções A, B, C |
| S21 | F07 | O crime dos dois relógios | Pendente de regras · texto importado |
| S22 | F08 | Os nove sinos sem um templo | Pendente de regras · texto importado |
| S23 | F08 | A homilia que partiu a assembleia | Pendente de regras · texto importado |
| S24 | F08 | O ídolo que ninguém reconheceu | Pendente de regras · texto importado |
| S25 | F09 | As sete bandeiras de pedra alta | Pendente de regras · texto importado |
| S26 | F09 | A última carroça do inverno | Pendente de regras · texto importado |
| S27 | F09 | A paz escrita com tinta emprestada | Pendente de regras · texto importado |
| S28 | F10 | A mão que assinava sozinha | Pendente de regras · texto importado |
| S29 | F10 | O voto dos nascidos da forja | Pendente de regras · texto importado |
| S30 | F10 | Os olhos sob a cúpula | Parcial jogável · opções A, B, C |
| S31 | F11 | O catálogo das vozes apagadas | Pendente de regras · texto importado |
| S32 | F11 | O caminho que o mapa esqueceu | Pendente de regras · texto importado |
| S33 | F11 | A fenda que respondia ao sino | Pendente de regras · texto importado |
| S34 | F12 | A escola das portas abertas | Pendente de regras · texto importado |
| S35 | F12 | A festa que não cabia na praça | Parcial jogável · opções A, C, D |
| S36 | F12 | O telhado depois da tempestade | Parcial jogável · opções A, D |

## Sagas

| ID | Atos importados | Estado | Consequências integradas |
|---|---:|---|---|
| N01 | 5 | Parcial jogável | Regência, legitimidade, prova de adoção, reforma e reconhecimento de título. |
| N02 | 5 | Parcial jogável | Encontro, convivência, recusa, pressão, casamento com dois aceites e registro de bens separados. |
| N03 | 5 | Parcial jogável | Falso positivo documentado, estatuto parcial ou votação de cidadania. |
| N04 | 5 | Parcial jogável | Gastos de saúde e Fluxo, exame ambiental, recuperação do rio e uso da licença de C01. |
| N05 | 5 | Parcial jogável | Incubação, habitat, preservação de memorial, recusa e possível corredor pactuado. |
| N06 | 6 | Parcial jogável | Escassez, preço de rota, mobilização, baixas, escombros e ratificação. |

As opções sem regra aparecem indisponíveis quando a cena é acessível. Cenas finais resumem o legado dos caminhos suportados. Carreira e residência de NPCs, adoção e divórcio sistêmicos, patrimônio transferível, sucessão completa e campanhas militares com múltiplas frentes permanecem pendentes. A arte reutiliza o acervo de pixel art, com retrato derivado da identidade do participante e escombros proporcionais ao dano.

## Arcos de 0.11 preservados

| ID | Arco | Ponto de integração |
|---|---|---|
| C01 | apprentice | Licença independente libera uma opção de N04 e uma semente. |
| C02 | inheritance | Casa pública libera S03. |
| C03 | ledger | Relato ou suspeita habilita S20. Suspensão de reservas pode abrir N06. |
| C04 | council | Tarifa preservada na viagem. Uma tarifa positiva pode ajudar a abrir N06. |
| C05 | flux | Mapa arcano habilita a via alternativa de N04 e S14. |
| C06 | dragon | Contato abre a possibilidade de S17 na região de N05. |

## Regras e persistência

| Efeito implementado | Executor e validação |
|---|---|
| Decisão, relógio e legado | `dossier/director.gd`: `validate_player`, `perform`, `advance`, `conclude`. Exige ato, prazo e local válidos. |
| Crédito e Fluxo do jogador | `engine.gd:dossier_choice`. Valida saldo antes de aplicar e restaura a cópia anterior em caso de falha ao salvar. |
| Reserva, tarifa, saúde, rio, habitat, legitimidade, tensão, dano | `dossier/director.gd:result_for`. Campos definidos e limitados por `METERS`. `engine.gd:expedition_route` e `expedition_condition` aplicam efeitos à viagem e ao assentamento. |
| Evidências e memória | `result_for` registra cidade, causa e dia no caderno ou na memória do ator. `check_action` impede o acesso a provas particulares e de outro local. |
| Regência, reforma, cidadania e dragões | `apply_special`. Apoio para votação e condições de território/consentimento dracônico. |
| Vínculo e casamento | `relationship_action`. Maioridade, respostas independentes e registro único de consentimento. |
| Mobilização, combate e tratado | `check_action`, `apply_special`, `resolve_front`. Autoridade, reservas, baixas, dano e ratificação bilateral. |
| Abertura compartilhada | `review_arc_candidate` e `publish_arc_candidates`. Revisão independente, hora de publicação, lock do mundo, fonte pública, versão, idempotência e auditoria. A abertura confirmada fica no feed com RLS e cursor. |

O campo opcional `dossier` tem versão própria. Saves anteriores são carregados sem reexecutar efeitos históricos e o primeiro avanço cria a estrutura. A gravação existente mantém backup anterior e substitui o arquivo ativo por renomeação. As amostras de migração usadas nos testes são fixtures estruturais, geradas no teste. O cliente online mantém seu cursor em memória e nunca grava no arquivo de campanha solo.

## Mestre no Supabase

As propostas antigas continuam pendentes até revisão autorizada. O publicador tem um efeito compartilhado implementado, a abertura de uma crônica baseada em evento público. A nova interface lê somente entradas confirmadas desse feed. A automação existente do Mestre ainda usa o intake 0.11 via conector SQL. A substituição por endpoint estruturado, as propostas para N01–N06, os desfechos com efeitos globais e a sincronização privada do solo online ficam pendentes.

## Verificação

| Critérios do dossiê | Resultado e limites |
|---|---|
| 01–03 | Conferidos IDs, famílias, escolhas e prazos dos dados, contagem dos atos e referências das opções executáveis. Variedade causal integral permanece parcial. |
| 04–05, 07–08, 15 | Regressão das seis Crônicas, legado de três gerações, tarifa e licença artesanal. Teste de recusa dracônica no motor. |
| 06, 09 | Cobertura parcial nas Crônicas anteriores. Sem validação global de boatos ou sistema geral de substituição de cargos. |
| 10–13 | Testados pressão, aceites individuais, menoridade, recusa e convivência independente. Presentes não fazem parte do fluxo do dossiê. |
| 14, 16–17 | Pendentes regras completas de divórcio, herança patrimonial e sucessão. |
| 18–21 | Testes de precondições, confronto, reserva, dano, acordo bilateral e avanço autônomo. Os testes de guerra usam uma fixture direta no motor. |
| 22–27 | Parcial. Testados licença, isolamento de evidência local, identidade reproduzível e avanço de uma saga por dez anos sem repetir efeitos. Sem simulação integral de gerações ou culpado procedural. |
| 28–29, 32 | Rodado offline e testado isolamento entre estados. Apenas 15 situações possuem regras iniciais. O solo privado sincronizado fica pendente. |
| 30–31, 33 | SQL em transação revertida testou revisão, versão, fontes, privilégios, RLS, rollback e reexecução serial. O lock está implementado. Concorrência simultânea e publicação automática no horário permanecem sem ensaio. |
| 34–35 | Navegação e visual contextual testados no Godot. Sem campanha visual de reconstrução ponta a ponta. |
| 36 | Fixtures 0.10/0.11 carregaram e preservaram dados de base e identidade; backup anterior conferido. |
| 37–39 | Consultar o resultado do GitHub Actions para a assinatura e o APK. O teste de UI em Godot não equivale à instalação em Android físico. |
| 40 | Estados discriminados neste relatório. |
