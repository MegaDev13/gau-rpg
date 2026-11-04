# Cinzas de Éter — primeiro capítulo

Campanha narrativa independente dos arquivos existentes da plataforma GAU. Godot 4.3, modo solo sem rede. Crie um personagem, tome decisões no distrito industrial e consulte o diário. Escolhas alteram confiança, créditos, estabilidade, conhecimento e a história; o progresso é salvo no armazenamento interno. O backup mantém o estado válido anterior e é usado quando o save principal estiver inválido. O início de uma campanha substitui o save atual.

## APK de teste

No GitHub, abra **Actions → Android APK**, escolha uma execução bem-sucedida da branch `feature/rpg-narrativo-mundo-vivo` e baixe o artifact `cinzas-de-eter-android-debug`. Extraia o ZIP, transfira o APK ao Android e instale-o autorizando a instalação da fonte quando solicitado. O APK de depuração usa uma chave temporária gerada em cada execução: instalações posteriores podem exigir a desinstalação da anterior, o que apagará o progresso. Uma chave estável protegida por secrets é necessária para atualizações sem perda de dados.

## Testes locais

Com Godot 4.3 instalado: `godot --headless --path rpg-narrativo --editor --import --quit` e `godot --headless --path rpg-narrativo --script res://tests.gd`. Testes usam o armazenamento próprio do projeto e substituem a campanha de teste local.

## Limitações atuais

Primeiro capítulo e quatro profissões selecionáveis; as profissões ainda não modificam escolhas. Não há multiplayer, contas, Supabase, simulação autônoma, casamento, exércitos ou tower defense. O workflow produz APK de depuração, não versão de distribuição. A instalação e execução em um aparelho físico dependem de teste separado.
