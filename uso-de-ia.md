# Registro de uso de IA

Registro de trabalho para apoiar a seção **9. Uso de IA** do artigo. O enunciado pede que essa seção diga, em 2 a 3 linhas, onde a IA foi usada e como suas contribuições foram verificadas. Este arquivo registra as interações enquanto acontecem; não substitui a seção do artigo.

## 17/11/2026 — Configuração do trabalho

- **Pedido:** configurar instruções para os agentes e uma skill para o ciclo de medição; trabalhar em uma branch por mudança, com pull request e merge em `main`.
- **Contribuição da IA:** leu o repositório novo e redigiu a seção de colaboração do `AGENTS.md` e a skill `ciclo` para Codex e Claude Code. O setup foi registrado no commit `0854c59`, enviado após pedido da pessoa.
- **Verificação feita:** as duas skills passaram na validação de formato; o diff foi conferido e o repositório ficou limpo após o push. Nenhuma mudança de performance foi feita nessa etapa.

## 17/11/2026 — Leitura inicial do código

- **Pedido:** explicar o funcionamento da aplicação e começar este registro.
- **Contribuição da IA:** descreveu o caminho da requisição pelo Express, pelas rotas e pela função de consulta ao PostgreSQL. Apontou aspectos do código para investigar, como a criação de uma conexão por consulta em `api/src/db.js`, as consultas dentro de loops em `api/src/rotas.js`, a agregação de vendas no JavaScript e o registro do corpo das respostas em `api/src/server.js`.
- **Verificação feita:** a descrição foi conferida diretamente nos arquivos citados. Essas observações são leitura do código, não diagnóstico medido. O contrato ainda não foi gravado, a linha de base ainda não foi medida e nenhuma hipótese de melhoria foi testada.

## 17/11/2026 — Contrato e linha de base

- **Pedido:** executar o ciclo inicial para obter as informações de base.
- **Contribuição da IA:** identificou que os containers da tentativa anterior usavam o mesmo nome e as mesmas portas; parou esses containers preservando seu volume e subiu esta cópia com `COMPOSE_PROJECT_NAME=desafio-novo`. Gravou o contrato original, executou três medições com `scripts/medir.sh 00-linha-de-base`, calculou as medianas a partir dos arquivos gerados e abriu o PR #2, posteriormente integrado em `main`.
- **Verificação feita:** cada `contexto.txt` registra os mesmos parâmetros, o commit do contrato e zero arquivos alterados sem commit; cada `contrato.txt` termina em “Contrato mantido”. Os arquivos de origem estão nas três pastas `resultados/*-00-linha-de-base/`. Nenhuma otimização foi aplicada e a causa dos tempos de resposta ainda não foi diagnosticada.

## 17/11/2026 — Diagnóstico das consultas SQL

- **Pedido:** examinar as consultas com `EXPLAIN` e verificar `pg_stat_statements` para localizar possíveis problemas.
- **Contribuição da IA:** preparou consultas de diagnóstico somente leitura, executou `EXPLAIN (ANALYZE, BUFFERS)` fora da carga, leu os planos e redigiu uma análise preliminar em `diagnostico/leitura-inicial.md`. Consultou a documentação oficial do PostgreSQL 16 para interpretar os planos e os requisitos de `pg_stat_statements`.
- **Verificação feita:** os SQLs e suas saídas integrais foram salvos em `diagnostico/`. O módulo `pg_stat_statements` estava disponível, mas inativo; não foi ativado, e nenhuma mudança de performance foi feita. Os tempos dos planos não foram tratados como latência da API.

## 17/11/2026 — Primeiro experimento de performance

- **Decisão da pessoa:** testar a busca em lote dos itens dos pedidos antes de uma consulta única com joins, por considerar maior o risco de quebra de contrato na segunda opção e por não assumir que menos chamadas SQL garantem melhor desempenho.
- **Contribuição da IA:** formulou a hipótese de trabalho a partir dessa decisão em `experimentos.md`, implementou a busca em lote em `api/src/rotas.js`, executou o verificador de contrato e três medições com o rótulo `01-itens-em-lote`, e comparou as medianas com a linha de base. Registrou a consulta única com joins em `proximos-testes.md` como alternativa futura.
- **Verificação feita:** a hipótese foi commitada antes do código; a alteração da API foi commitada antes das medições; os três `contexto.txt` registram árvore limpa e parâmetros iguais aos da base; os três `contrato.txt` terminam em “Contrato mantido”. A interpretação e seus limites estão em `experimentos.md`, com links para os arquivos gerados em `resultados/`.

## 17/11/2026 — Repetição da H1 com Chrome fechado

- **Correção da pessoa:** o Google Chrome estava fechado na linha de base e aberto somente na primeira rodada de medição da busca em lote. A pessoa confirmou que o fechou para repetir o teste.
- **Contribuição da IA:** executou mais três medições da mesma implementação, com o rótulo `01-itens-em-lote-chrome-fechado`, validou contexto e contrato e atualizou a comparação em `experimentos.md`. Manteve as medições anteriores intactas e identificadas como rodada com condição diferente.
- **Verificação feita:** os três novos `contexto.txt` registram parâmetros iguais aos da base e árvore limpa; os três `contrato.txt` terminam em “Contrato mantido”. O script não registra aplicativos abertos no host, então a condição do Chrome é uma informação fornecida pela pessoa, não uma medição automática.

## 17/11/2026 — Escolha do pool de conexões

- **Uso relatado pela pessoa:** consultou o ChatGPT em um chat separado para estudar `pg.Pool` e PgBouncer com explicações visuais, incluindo SVGs.
- **Contribuição da IA:** o Codex explicou onde cada opção reutiliza conexões e comparou os custos para o Compose do desafio. Sugeriu testar primeiro `pg.Pool` e discutiu como o tamanho do pool afeta a fila de consultas.
- **Decisão da pessoa:** escolher `pg.Pool` com até 10 conexões para a única instância Node.js. Considerou o PgBouncer mais adequado se múltiplas instâncias com pools próprios precisassem compartilhar conexões com o banco.

- **Execução e verificação:** o Codex implementou um único `pg.Pool` com `max: 10`, verificou o contrato e executou as medições. A primeira rodada ficou registrada como exploratória depois de um processo do Chrome aparecer entre rodadas. A comparação em `experimentos.md` usa três rodadas nas quais as verificações não detectaram o navegador. Os 42 casos do contrato passaram antes da carga e depois de cada rodada.

## 17/11/2026 — Índice de pedidos por cliente

- **Contribuição da IA.** O Codex leu o plano da consulta de pedidos por cliente e comparou índices simples, compostos e de expressão. Sugeriu começar pelo índice simples em `pedidos(cliente_id)` para medir o efeito sobre uma consulta que já tinha um plano salvo.
- **Decisão e previsões da pessoa.** Escolheu o índice simples em `pedidos(cliente_id)`. Levantou a hipótese de ganho de vazão com um índice em `lower(email)` e de que a CPU do banco pode continuar perto de 99% com o teste de 20 usuários, porque cada resposta libera o usuário virtual para enviar outra requisição.

- **Execução e verificação.** O Codex escreveu a hipótese antes do código, adicionou um único índice em um arquivo SQL novo, subiu um banco isolado e verificou as 42 respostas. Executou três medições, calculou as medianas com os arquivos gerados e salvou o plano e o tamanho do índice em `diagnostico/indice-pedidos-cliente.txt`.

## 17/11/2026 — Teste do pool com o índice

- **Pedido da pessoa.** Comparar a combinação de lote, índice e pool de 10 conexões e conferir os números da linha de base. Depois que fechou o Chrome, pediu para repetir as medições da combinação e desconsiderar as tentativas anteriores.
- **Contribuição da IA.** Conferiu os `resumo.txt` da base e das variantes intermediárias. Atualizou a branch do pool com a `main`, preservou os registros dos dois experimentos e manteve o banco do teste do índice. Validou o contrato, repetiu a carga três vezes com o Chrome fechado e registrou as medianas em `experimentos/pool-com-indice.md`.

## 17/11/2026 — Índice dos itens por pedido

- **Decisão e previsão da pessoa.** Propôs um índice simples em `itens_pedido(pedido_id)` para localizar itens pelo pedido. Previu mais requisições por segundo e p95 geral menor, dado o custo da busca existente.
- **Contribuição da IA.** Executou o plano da consulta em lote em uma transação somente leitura, confirmou a varredura em `itens_pedido` e salvou a saída. Comparou o índice simples com o composto e registrou a hipótese e o critério de medição antes da alteração.

- **Execução e verificação.** O Codex adicionou o índice em um arquivo SQL novo, manteve as configurações da API e do pool e validou as 42 respostas. Fez três rodadas, comparou as medianas e salvou o plano com índice e o espaço ocupado. As duas previsões ficaram registradas antes do commit do índice.

## 17/11/2026 — Diagnóstico com `pg_stat_statements`

- **Pedido da pessoa.** Ativar a coleta de consultas na versão atual para identificar os próximos pontos de investigação. A pessoa escolheu rodar com o Chrome fechado.
- **Contribuição da IA.** Ativou a extensão em um banco isolado, verificou o contrato, zerou os contadores após o aquecimento e coletou o ranking durante a carga desta API. Salvou a saída e os planos das consultas prioritárias e propôs começar pela página de pedidos por status.
- **Verificação.** As 42 respostas do contrato passaram. O ranking, os planos e as instruções de reprodução estão em `diagnostico/pg-stat-statements/`. As hipóteses de otimização ficaram em `proximos-testes.md`.

## 18/11/2026 — Diagnóstico de pedidos por status

- **Pedido da pessoa.** Priorizar a página de pedidos por status, diagnosticar as causas e comparar alternativas com fontes que incluíssem casos e artigos de empresas.
- **Contribuição da IA.** Separou a página da contagem no ranking sob carga, executou 21 planos em uma transação somente leitura e conferiu uma variante de seleção explícita. Leu os relatos de Shopify, GitLab e Citus Data e registrou quais técnicas preservam o contrato. Salvou as evidências e as alternativas em `diagnostico/pedidos-por-status/`.

## 18/11/2026 — Escolha do índice para pedidos por status

- **Decisão da pessoa.** Escolheu testar o índice composto em `pedidos(status, criado_em DESC, id DESC)`. Considerou que a troca para cursor mudaria a maneira como o cliente usa a API e que o ganho não justifica esse custo agora. Pediu manter a opção como experimento futuro.
- **Contribuição da IA.** Explicou a diferença entre filtrar e ordenar, relacionou os casos do GitLab, Shopify e Citus Data ao código local e registrou a hipótese, a referência e a medição antes da alteração.

- **Execução e verificação.** O Codex implementou apenas o índice, confirmou o contrato, mediu três vezes com a carga de referência e repetiu os 21 planos. Registrou os ganhos, os casos em que a ordenação permaneceu, o tamanho do índice e os picos encontrados em `recursos.csv`.

## 18/11/2026 — Diagnóstico de top produtos

- **Pedido da pessoa.** Investigar a próxima rota, `top-produtos`, explicar o problema e comparar alternativas com fontes de engenharia.
- **Contribuição da IA.** Leu a rota, fez quatro planos somente leitura e comparou os 50 primeiros produtos nos dois formatos de consulta. Pesquisou os casos de Sisense, Crunchy Data e Algolia. Salvou a comparação e propôs um teste de carga com a reescrita em SQL.

## H6 — Reescrita da consulta de top produtos

- **Contribuição da IA.** Propôs somar por ID antes do join com o catálogo e explicou, com o caso da Sisense, por que o cálculo pode acontecer antes da busca por nome e categoria.
- **Decisão da pessoa.** Escolheu seguir com a reescrita. Questionou a defasagem de uma view materializada entre refreshes num cenário em que novas vendas precisam aparecer no ranking.
- **Verificação.** O Codex mudou apenas o SQL, aplicou a revisão sobre o volume da H5, validou as 42 respostas e executou três rodadas com a régua original. As medianas e o consumo de recursos foram calculados a partir dos arquivos gerados. [Resultado da H6](experimentos.md#resultado-da-h6)
- **Decisão após medir.** A pessoa escolheu manter a H6 e pediu para conferir o p50 geral. O Codex conferiu os três resumos da H5 e da H6, registrou a decisão e integrou o PR #11.

## 18/11/2026 — Revisão após a H6

- **Pedido da pessoa.** Reler o código, levantar os principais gargalos restantes e propor alternativas. Também pediu confirmação de que as conversas e decisões estavam sendo registradas.
- **Contribuição da IA.** Releu as rotas e o middleware, cruzou os suspeitos com os três resumos da H6 e conferiu referências do PostgreSQL, GitLab e Sisense. Executou planos somente leitura para vendas por dia, busca por e-mail, busca de produtos e pedidos por status. Sugeriu levar a agregação de vendas por dia ao banco como próximo experimento.
- **Verificação.** Salvou o SQL, a saída integral e a comparação de opções. Os tempos HTTP citados vêm das rodadas da H6. A revisão não aplicou as alternativas na API nem mediu sua carga. [Revisão após a H6](diagnostico/pos-h6/README.md)
