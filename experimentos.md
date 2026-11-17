# Experimentos

## H1 — Itens dos pedidos em lote

- **Decisão da pessoa, antes da mudança:** testar primeiro a busca em lote dos itens. A consulta única com todos os joins fica como alternativa para testar depois, por ter maior risco de alterar o contrato; uma única ida ao banco não garante menor trabalho total.
- **Hipótese de trabalho, formulada a partir dessa decisão:** buscar de uma vez os itens dos pedidos de um cliente, junto com os nomes dos produtos, deve reduzir as consultas repetidas da rota `GET /clientes/:id/pedidos` e melhorar seu tempo de resposta sob carga sem mudar status, campos, valores ou ordem da resposta.
- **Previsão antes da medição:** para o cliente 7 usado no diagnóstico, o fluxo de 17 consultas SQL passa a 3 (verificação do cliente, pedidos e lote de itens com produtos). Espera-se redução do p95 dessa rota e possível melhora do resultado geral; o tamanho do efeito e o consumo de CPU e memória ainda são desconhecidos. Sem índices novos, a consulta em lote ainda pode varrer `itens_pedido`.
- **Evidência e leitura da ideia:** [diagnóstico local](diagnostico/leitura-inicial.md), [comparação com `ANY` na documentação do PostgreSQL 16](https://www.postgresql.org/docs/16/functions-comparisons.html) e [consultas parametrizadas no node-postgres](https://node-postgres.com/features/queries).
- **Como julgar:** contrato mantido; três medições com o mesmo rótulo e parâmetros da [linha de base](resultados/20261117-020419-00-linha-de-base/contexto.txt); comparação das medianas gerais e da rota, com CPU e memória dos serviços. Os valores de antes e depois serão preenchidos somente depois da medição.
- **Status:** aplicada e medida.

### Resultado da H1

| Ideia aplicada | Fonte | Status | Antes (mediana de 3) | Depois (mediana de 3) | Pastas das medições | Conclusão |
| --- | --- | --- | --- | --- | --- | --- |
| Itens dos pedidos em lote, sem índices ou pool novos | [diagnóstico](diagnostico/leitura-inicial.md), [PostgreSQL: `ANY`](https://www.postgresql.org/docs/16/functions-comparisons.html) e [node-postgres: parâmetros](https://node-postgres.com/features/queries) | Aplicada e medida | 2,87 req/s; p95 geral 21.354,1 ms; p95 da rota 24.349,4 ms | 4,57 req/s; p95 geral 12.015,7 ms; p95 da rota 11.299,7 ms | Antes: [B1](resultados/20261117-020419-00-linha-de-base/), [B2](resultados/20261117-020610-00-linha-de-base/), [B3](resultados/20261117-020801-00-linha-de-base/). Depois, com Chrome fechado: [L1](resultados/20261117-030752-01-itens-em-lote-chrome-fechado/), [L2](resultados/20261117-030935-01-itens-em-lote-chrome-fechado/), [L3](resultados/20261117-031120-01-itens-em-lote-chrome-fechado/). | Nesta carga, as três execuções do lote tiveram mais req/s e p95 geral menor que as três da base. O contrato foi mantido. O banco permaneceu próximo do limite de CPU; redução de custo absoluto não foi demonstrada. |

| Recurso durante a carga | Antes (mediana das médias) | Depois (mediana das médias) |
| --- | ---: | ---: |
| CPU do banco | 98,5% | 99,8% |
| Memória do banco | 405,7 MiB | 412,4 MiB |
| CPU da API | 5,9% | 6,5% |
| Memória da API | 32,8 MiB | 35,1 MiB |

Os limites dos containers continuaram iguais. Nas três novas pastas, cada `contexto.txt` registra 20 VUs, 60s, semente 42, o commit `e3d0543` e `arquivos alterados sem commit: 0`; cada `contrato.txt` termina em “Contrato mantido”. A comparação usa os arquivos `resumo.txt` e `recursos.txt` das pastas acima. Não medimos custo monetário nem isolamos quanto do ganho veio de menos consultas, menos conexões ou uma única varredura de itens por requisição.

### Repetição por condição da máquina

Após a primeira rodada, a pessoa informou que o Google Chrome estava fechado durante a linha de base e aberto apenas durante aquela primeira medição do lote. Por isso, repetimos **somente o lote** com o Chrome fechado, segundo confirmação da pessoa, e usamos a repetição como “depois” principal na tabela acima. O `medir.sh` não registra os programas abertos no host; essa condição foi informada pela pessoa e não pode ser reconstruída a partir dos arquivos de medição.

A primeira rodada do lote permanece preservada em [A1](resultados/20261117-025739-01-itens-em-lote/), [A2](resultados/20261117-025923-01-itens-em-lote/) e [A3](resultados/20261117-030107-01-itens-em-lote/). Suas medianas foram 4,38 req/s, p95 geral 12.394,1 ms e p95 da rota 11.501,6 ms. Ela não é a comparação principal porque a condição do Chrome diferia da linha de base. A repetição foi feita com a mesma implementação da API do commit `38fd459`; `e3d0543` acrescentou apenas documentação e os resultados da primeira rodada.

## H2 — Reutilizar conexões com `pg.Pool`

- **Decisão da pessoa antes da mudança:** testar um pool do `pg` com até 10 conexões. A aplicação usa uma única instância de Node.js. A pessoa considerou o PgBouncer mais adequado quando várias instâncias precisam compartilhar as conexões com o PostgreSQL.
- **Hipótese:** reaproveitar conexões entre consultas elimina parte do trabalho de abrir e fechar sessões e pode aumentar as requisições por segundo e reduzir o p95 geral.
- **Previsão:** com 10 conexões e 20 usuários virtuais, consultas podem esperar no pool. A redução da concorrência pode aliviar a disputa por CPU no PostgreSQL ou alongar a espera de consultas rápidas atrás de consultas lentas. O teste mede o efeito conjunto do reuso e do limite de 10. O consumo de CPU e memória será observado nos dois serviços.
- **Como julgar:** manter as respostas do contrato e comparar a mediana de três execuções com 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42. Usar a rodada de itens em lote com Chrome fechado como referência imediata e a linha de base original como referência do ganho acumulado.
- **Leitura:** [Pooling no node-postgres](https://node-postgres.com/features/pooling), [tamanho do pool](https://node-postgres.com/guides/pool-sizing) e [modos do PgBouncer](https://www.pgbouncer.org/features.html).

### Resultado da H2

Mediana de três rodadas por versão. Para cada recurso, a tabela usa a mediana das médias de cada rodada.

| Métrica | Base original | Itens em lote | Lote + pool de 10 |
| --- | ---: | ---: | ---: |
| Requisições/s | 2,87 | 4,57 | 5,14 |
| p50 geral | 1.299,9 ms | 1.302,7 ms | 2.194,6 ms |
| p95 geral | 21.354,1 ms | 12.015,7 ms | 8.788,3 ms |
| p99 geral | 25.935,8 ms | 26.989,3 ms | 10.878,9 ms |
| Erros HTTP | 0,00% | 0,00% | 0,00% |
| CPU média do banco | 98,5% | 99,8% | 99,6% |
| Memória média do banco | 405,7 MiB | 412,4 MiB | 379,4 MiB |
| CPU média da API | 5,9% | 6,5% | 6,4% |
| Memória média da API | 32,8 MiB | 35,1 MiB | 86,3 MiB |

Arquivos gerados pelo script. Base original [B1](resultados/20261117-020419-00-linha-de-base/), [B2](resultados/20261117-020610-00-linha-de-base/), [B3](resultados/20261117-020801-00-linha-de-base/). Lote [L1](resultados/20261117-030752-01-itens-em-lote-chrome-fechado/), [L2](resultados/20261117-030935-01-itens-em-lote-chrome-fechado/), [L3](resultados/20261117-031120-01-itens-em-lote-chrome-fechado/). Lote com pool [P1](resultados/20261117-204120-02-pool-10-chrome-fechado/), [P2](resultados/20261117-204251-02-pool-10-chrome-fechado/), [P3](resultados/20261117-204421-02-pool-10-chrome-fechado/). Os números vêm de `resumo.txt` e `recursos.txt`.

As três rodadas do pool tiveram mais requisições por segundo (5,10 a 5,25 contra 4,52 a 4,80) e p95 geral menor (8.621,7 a 8.892,6 ms contra 10.903,8 a 12.149,6 ms). O p50 geral subiu em todas as rodadas (2.192,7 a 2.297,0 ms contra 1.301,5 a 1.580,3 ms), e a memória média da API aumentou. O banco seguiu perto do limite de CPU.

O efeito variou por rota. A mediana dos p95 de pedidos por status caiu de 20.910,1 para 7.494,0 ms. A de cliente por ID subiu de 495,0 para 2.194,3 ms. A espera por uma conexão pode contribuir para essa piora. Medimos a latência HTTP, que inclui tanto a espera como a execução do SQL. Os números capturam o efeito combinado da reutilização e do limite de 10 conexões.

Os arquivos `contexto.txt` das três rodadas do pool registram o commit `562badb`, a árvore limpa e os mesmos parâmetros e limites das referências. As 42 respostas passaram no contrato antes da carga e depois de cada execução. O lote de referência foi medido mais cedo no mesmo dia. O Compose foi iniciado novamente para a H2 com o volume existente e cada rodada teve o aquecimento padrão.

A [primeira rodada do pool](resultados/20261117-203902-02-pool-10/) foi preservada como exploratória. O Chrome apareceu entre a primeira e a segunda rodada planejadas, e a condição durante toda a primeira rodada ficou incerta. Nas três rodadas da comparação, uma verificação externa ao `medir.sh` procurou processos ativos do navegador antes, em intervalos de cinco segundos durante a execução e ao final. As verificações não detectaram Chrome ou Chromium.
