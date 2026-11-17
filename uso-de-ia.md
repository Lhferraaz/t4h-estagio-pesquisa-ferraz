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
