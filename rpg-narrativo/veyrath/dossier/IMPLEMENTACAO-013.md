# Veyrath 0.13 · Fechamento narrativo

Branch `feature/rpg-narrativo-mundo-vivo`, base `3a4941564474b1fb7b516118edbef346075c1c85`. Versão Android `0.13.0`, code 13. A Bíblia, os textos e IDs de 0.12, as 12 famílias e as seis Crônicas legadas foram mantidos.

## Cobertura por opção

**Executada em fixture** significa que o Godot percorreu a regra com seus requisitos satisfeitos, verificou um evento e recusou nova execução. Não significa que todos os sistemas subjacentes ou todos os epílogos do dossiê estejam completos. Valores de custo e requisitos, efeitos e resultados por opção estão em [rules.json](rules.json). A apresentação literária continua em [scenarios.json](scenarios.json) e [sagas.json](sagas.json).

| Situação | Gatilho | A | B | C | D |
|---|---|---|---|---|---|
| S01 | `estate` | `inventory_estate` | `buy_share` | `contest_estate` | `settle_estate` |
| S02 | `adoption` | `adopt` | `buy_share` | `rumor` | `settle_estate` |
| S03 | `public_house` | `s03_provenance` | `sell_assets` | `contest_estate` | `institution` |
| S04 | `relationship` | `date` | `flexible_work` | `friends` | `pause` |
| S05 | `cohabitation` | `cohabit` | `household_agreement` | `pressure` | `dissolve_household` |
| S06 | `commitment` | `marriage` | `pause` | `household_agreement` | `friends` |
| S07 | `vacancy` | `succession` | `regency` | `unilateral` | `succession` |
| S08 | `adoption` | `adopt` | `law` | `succession` | `law` |
| S09 | `concession` | `investigate` | `contract` | `rumor` | `contract` |
| S10 | `wages` | `employment` | `institution` | `mandate` | `employment` |
| S11 | `scarcity` | `supply, health` | `supply, route` | `supply, tension` | `s11_prices` |
| S12 | `independent_artisan` | `sustainable_contract` | `guild_consorcio` | `contract` | Decisão registrada |
| S13 | `medical` | `s13_protocol` | `employment` | `health, river` | `river, health` |
| S14 | `flux_record` | `s14_replication` | `legitimacy` | `rumor` | `river` |
| S15 | `rail` | `logistics` | `logistics` | `hazard` | `logistics` |
| S16 | `nest` | `safe_nest` | `logistics` | `investigate` | `n05_incubation` |
| S17 | `dragon_contact` | `memorial_respect` | `dragon_consent` | `dragon_consent` | `dragon_refusal` |
| S18 | `damaged_river` | `n04_water` | `risk_downstream` | `contract` | `habitat` |
| S19 | `absence` | `investigate` | `investigate` | `rumor` | `investigate` |
| S20 | `ledger_report` | `s20_checks` | `press_claim` | `protected_source` | `publication_hold` |
| S21 | `observatory` | `investigate` | `investigate` | `rumor` | `investigate` |
| S22 | `religious` | `institution` | `law` | `institution` | `publication_hold` |
| S23 | `implants` | `investigate` | `law` | `law` | `law` |
| S24 | `relic` | `investigate` | `custody` | `rumor` | `custody` |
| S25 | `border` | `diplomacy` | `logistics` | `war_order` | `diplomacy` |
| S26 | `blockade` | `convoy` | `logistics` | `mandate` | `blockade` |
| S27 | `diplomacy` | `truce` | `prisoner_exchange` | `offensive` | `diplomacy` |
| S28 | `eidrino` | `civil_rights` | `investigate` | `appeal` | `appeal` |
| S29 | `suffrage` | `citizenship_vote` | `civil_rights` | `appeal` | `succession` |
| S30 | `sensor` | `n03_false_positive` | `sensor_suspended` | `tension` | `appeal` |
| S31 | `archive` | `investigate` | `investigate` | `rumor` | `custody` |
| S32 | `exploration` | `survey_route` | `investigate` | `rumor` | `survey_route` |
| S33 | `rupture` | `investigate` | `contract` | `hazard` | `appeal` |
| S34 | `school` | `institution` | `institution` | `appeal` | `institution` |
| S35 | `festival` | `festival_public` | `contract` | `supply` | `shelter_fund` |
| S36 | `storm` | `repaired` | `repair` | `repair` | `health` |

Todas as situações acima tiveram abertura controlada, avanço autônomo e desfecho verificados em teste. Os gatilhos em campanha dependem de cidade, contexto e dia. Alguns são calendários locais, e a campanha não foi percorrida ponta a ponta para as 36 situações.

| Saga e ato | A | B | C | D |
|---|---|---|---|---|
| N01.1 | `titles` | `regency` | `war_order` | `hearing` |
| N01.2 | `n01_adoption` | `mediation` | `dynastic_rumor` | `constitution` |
| N01.3 | `observers` | `civil_relief` | `offensive` | `law` |
| N01.4 | `constitutional_vote` | `regency` | `unilateral` | `recognize_title` |
| N01.5 | — | — | — | — |
| N02.1 | `talk` | `talk` | `pressure` | `pause` |
| N02.2 | `date` | `cohabit` | `friends` | `pressure` |
| N02.3 | `cohabit` | `apart` | `relocate` | `separate` |
| N02.4 | `marriage` | `union` | `pause` | `friends` |
| N02.5 | — | — | — | — |
| N03.1 | `citizen_case` | `temporary_representation` | `tension` | `relocate` |
| N03.2 | `n03_false_positive` | `sensor_suspended` | `appeal` | `legitimacy` |
| N03.3 | `civic_assembly` | `tension` | `rumor` | `citizen_case` |
| N03.4 | `citizenship_vote` | `civil_rights` | `appeal` | `court_review` |
| N03.5 | — | — | — | — |
| N04.1 | `monitored` | `health, river` | `health, river` | `rail_order` |
| N04.2 | `n04_water` | `river, health` | `risk_downstream` | `safer_method` |
| N04.3 | `supply, health` | `lenses` | `lenses` | `contract` |
| N04.4 | `water_limit` | `law` | `transfer_plant` | `reparation` |
| N04.5 | — | — | — | — |
| N05.1 | `safe_nest` | `logistics` | `hazard` | `n05_incubation` |
| N05.2 | `n05_memorial` | `route, habitat` | `tension, habitat` | `habitat` |
| N05.3 | `memorial_respect` | `dragon_consent` | `dragon_refusal` | `dragon_refusal` |
| N05.4 | `corridor` | `detour` | `dragon_refusal` | `habitat` |
| N05.5 | — | — | — | — |
| N06.1 | `supply, health` | `n06_shortage` | `supply, tension` | `supply` |
| N06.2 | `labor_agreement` | `labor_agreement` | `supply, tension` | `supply, tension` |
| N06.3 | `diplomatic_channel` | `civil_convoy` | `war_order` | `supply` |
| N06.4 | `diplomatic_channel` | `defense_supply` | `supply, health` | `humanitarian` |
| N06.5 | `ratify` | `truce` | `reconstruction_fund` | `offensive` |
| N06.6 | — | — | — | — |

N05.1 B/C, N05.4 C e N06.5 D seguem a ação descrita no texto autoral. Há divergências em relação ao resumo funcional do anexo. A remoção é condicionada à segurança dos ovos, uma tentativa de captura pode causar avaria, a coerção é recusada e a escalada exige força abastecida.

## Sistemas e evidência

| Funcionalidade | Estado e teste |
|---|---|
| 144 escolhas de situações, 100 de sagas | **Execução em fixture verificada.** [coverage_tests.gd](coverage_tests.gd) confronta os IDs, executa cada opção, verifica o registro único e tenta duplicá-la. Também testa o encerramento das 36 situações por prazo. |
| Propriedade, adoção e sucessão familiar | **Parcial.** Testados parentesco persistente após morte, duas cotas, custódia separada, dívida paga pelo espólio e execução idempotente. Nascimento, autonomia por idade, testamentos e falência ainda faltam. [civic_tests.gd](civic_tests.gd) |
| Vida familiar, profissão e residência | **Parcial.** Consentimento individual, registro de despesas separadas, pedidos de partilha, renda/turno e mudança com dia de chegada. Testes cobrem recusa e chegada. Dissolução civil completa, guarda, aposentadoria, histórico de renda recebido e encontros em todos os destinos ainda faltam. |
| Leis e cargos | **Parcial.** Testados titular de regência, expiração, vacância e vigência prospectiva com cotas preservadas. Disputa dinástica completa, candidaturas com provas e eleições por jurisdição ainda faltam. |
| Guerra e tratados | **Parcial.** Testados autoridade, efetivo, abastecimento, baixas, escombros, ordem idempotente, tratado bilateral e save. Faltam várias frentes ligadas, ocupação administrativa, troca efetiva de prisioneiros e campanhas completas de reconstrução. |
| Provas e boatos | **Parcial.** Testados fixação da causa em S21, boato sem conceder prova e limites locais do caderno. Investigações completas, julgamento e revelação por ator ainda faltam. |
| Finais de saga | **Parcial.** Os finais usam estados civis, políticos, ambientais e militares. Ainda faltam alguns epílogos e suas transições de longo prazo. |
| Mestre multiplayer | **Parcial.** A migração `20261104204654` adiciona seis resoluções tipadas das Crônicas legadas. O operador revisa antes da aplicação. O worker valida versão, fonte, alvo e reservas e grava efeito e feed no mesmo commit. Testes executados em transação revertida e em mundos descartáveis com dois backends e cron isolado. Faltam propostas de evolução da automação, desfechos completos N01–N06 e sincronização solo online. |
| Interface | **Parcial.** Dossiê, espólios e família, gabinete, frentes, jornal e transferência de campanha. Reutilização de cenários e retratos em pixel art. Faltam variantes completas de idade, histórico de cicatrizes e áudio distinto para todos os atos. |
| Saves | **Testado no Godot.** Fixtures 0.10/0.11, estado 0.12 sem registro cívico, importação com backup, adulteração rejeitada, reload de frente e regressão de atualização remota. A transferência está em Configurações a partir da 0.13. A versão 0.12 instalada não ganha esse botão retroativamente. |
| Android | **Separação dos canais.** A distribuição com package original exige `VEYRATH_DEBUG_KEYSTORE_BASE64` e `VEYRATH_ANDROID_CERT_SHA256` correspondente. Sem os dois, a build de teste usa outro package por execução. Essa instalação pode coexistir com a 0.12 e não transfere automaticamente o save. Sem configuração do segredo e duas execuções verificadas, a estabilidade do certificado não está comprovada. |

Ver também [mecanismos do motor](civic.gd), [teste de publicação SQL](../../supabase/test_gm_arc_resolution.sql) e [GitHub Actions](https://github.com/MegaDev13/gau-rpg/actions/workflows/android-apk.yml). O teste headless e as capturas em CI não comprovam instalação em dispositivo físico.
