# Experimentos

Na preparação do artigo, selecionamos leituras científicas para aprofundar a interpretação dos experimentos. A Lei de Little ajuda a ler carga, vazão e latência média. O artigo de Selinger e colegas ajuda a explicar a escolha de caminhos de acesso e o papel da ordenação nos planos de consulta. Os valores observados vêm das rodadas registradas abaixo.

## Alternativas consideradas e descartadas

| Onde | Alternativa | Motivo do descarte |
| --- | --- | --- |
| Conexões | Abrir uma conexão com o PostgreSQL por requisição HTTP | Nas rotas que executam um único SQL, a abertura continuaria acontecendo a cada requisição. O `pg.Pool` permite reaproveitar conexões entre requisições. |
| Conexões | Adicionar PgBouncer | A aplicação tem um processo Node.js. A pessoa escolheu o pool do `pg` e deixou o PgBouncer fora deste cenário. Ele pode voltar à discussão se várias instâncias precisarem compartilhar conexões com o banco. |
| Conexões | Reduzir o pool de dez para quatro conexões (H11) | Nas três rodadas, o p95 e o p99 gerais melhoraram. O p50 geral subiu de 495,8 para 600,6 ms, e o p50 piorou nas cinco rotas que somam 90% do peso da carga. A memória média do PostgreSQL também subiu. A pessoa autora decidiu manter dez conexões na entrega. [Resultado da H11](#resultado-da-h11) |
| Pedidos por status | Substituir o número da página por um cursor | O contrato aceita saltar direto para uma página, inclusive a 15.000. Um cursor exige um ponto de partida, como o último pedido da página anterior. [Diagnóstico da paginação](diagnostico/pedidos-por-status/README.md#relatos-de-engenharia-e-artigos) |
| Pedidos por status | Devolver uma estimativa no campo `total` | O contrato exige a contagem exata dos pedidos no status escolhido. A estimativa poderia devolver um valor diferente. [Consulta e alternativas de contagem](diagnostico/pedidos-por-status/README.md#alternativas-para-experimentar) |

As propostas ainda em aberto estão em [Próximos testes](proximos-testes.md).

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

**Leitura da carga.** A Lei de Little relaciona a quantidade média de requisições em andamento à vazão e ao tempo médio de resposta. No cenário fechado do k6, cada usuário virtual envia a próxima requisição quando a atual termina. Com os mesmos usuários virtuais, ciclos mais curtos podem aumentar a vazão. Os percentis vêm das medições. [John D. C. Little, *Little's Law as Viewed on Its 50th Anniversary*, Operations Research, 2011](https://pubsonline.informs.org/doi/abs/10.1287/opre.1110.0940?journalCode=opre)

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

## H3 — Índice simples nos pedidos por cliente

- **Decisão da pessoa.** Testar um índice B-tree simples em `pedidos(cliente_id)`. Ela também levantou a hipótese de que um índice em `clientes(lower(email))` pode aumentar bastante as requisições por segundo. O índice de e-mail é uma hipótese separada.
- **Previsão da pessoa.** O banco pode continuar perto de 99% de CPU mesmo com ganho de vazão. Na carga com usuários virtuais fixos, cada usuário inicia outra requisição depois da resposta, ocupando a capacidade que a melhoria liberar.
- **Hipótese de trabalho.** O índice de `cliente_id` deve permitir localizar os pedidos de um cliente com menos acessos a blocos que a varredura paralela do plano inicial. Esperamos menor latência na rota `GET /clientes/:id/pedidos` e possível ganho de vazão geral. A consulta em lote dos itens continua fazendo parte da rota.
- **Como julgar.** Comparar os planos para o cliente 7, consultar o espaço ocupado pelo índice e validar as 42 respostas do contrato. Repetir três vezes com 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42. Comparar com a busca em lote na `main` e com a linha de base original. O PR do pool ainda está aberto, então a H3 parte da `main` com a H1.
- **Leitura.** [Plano inicial](diagnostico/explain-consultas.txt#L33), [B-tree no PostgreSQL 16](https://www.postgresql.org/docs/16/indexes-intro.html) e [índices de expressão](https://www.postgresql.org/docs/16/indexes-expressional.html).

### Resultado da H3

Mediana de três rodadas por versão. Para CPU e memória, a tabela usa a mediana das médias de cada rodada.

| Métrica | Base original | Itens em lote | Lote + índice |
| --- | ---: | ---: | ---: |
| Requisições/s | 2,87 | 4,57 | 5,46 |
| p50 geral | 1.299,9 ms | 1.302,7 ms | 1.302,0 ms |
| p95 geral | 21.354,1 ms | 12.015,7 ms | 11.520,0 ms |
| p95 de pedidos do cliente | 24.349,4 ms | 11.299,7 ms | 7.901,9 ms |
| Erros HTTP | 0,00% | 0,00% | 0,00% |
| CPU média do banco | 98,5% | 99,8% | 99,5% |
| Memória média do banco | 405,7 MiB | 412,4 MiB | 397,5 MiB |
| CPU média da API | 5,9% | 6,5% | 7,6% |
| Memória média da API | 32,8 MiB | 35,1 MiB | 37,4 MiB |

Arquivos de origem. Base original [B1](resultados/20261117-020419-00-linha-de-base/), [B2](resultados/20261117-020610-00-linha-de-base/), [B3](resultados/20261117-020801-00-linha-de-base/). Lote [L1](resultados/20261117-030752-01-itens-em-lote-chrome-fechado/), [L2](resultados/20261117-030935-01-itens-em-lote-chrome-fechado/), [L3](resultados/20261117-031120-01-itens-em-lote-chrome-fechado/). Lote com índice [I1](resultados/20261117-210544-03-indice-pedidos-cliente/), [I2](resultados/20261117-210713-03-indice-pedidos-cliente/), [I3](resultados/20261117-210845-03-indice-pedidos-cliente/). Os números vêm de `resumo.txt` e `recursos.txt`.

As três rodadas com o índice tiveram maior vazão (5,45 a 5,62 contra 4,52 a 4,80 req/s) e menor p95 na rota de pedidos do cliente (7.674,4 a 8.292,4 ms contra 10.906,5 a 11.802,3 ms). As faixas de p95 geral se sobrepõem (10.325,1 a 11.860,3 ms com o índice e 10.903,8 a 12.149,6 ms com o lote). A CPU média do banco continuou perto do limite. A carga usa usuários virtuais fixos e mede quantas requisições conseguem completar, sem fixar a taxa de chegada.

A consulta de pedidos do cliente 7 retornou as mesmas cinco linhas. Na consulta original o plano usou `Parallel Seq Scan` em `pedidos`. O novo plano usou `Index Scan` com `Index Cond: (cliente_id = 7)` e manteve a ordenação das cinco linhas. No nó que acessa `pedidos`, o plano original registrou `shared hit=6643 read=14191` e o novo `shared hit=6 read=2`. O tamanho do índice foi de 5.857.280 bytes (`5720 kB` no PostgreSQL). Esses planos foram coletados fora da carga, em momentos diferentes. O teste HTTP usa rotas de leitura. [Plano inicial](diagnostico/explain-consultas.txt#L33) · [Plano com índice e tamanho](diagnostico/indice-pedidos-cliente.txt)

O índice foi criado na inicialização de um banco isolado, com os dados gerados pelos scripts do desafio. A referência do lote foi medida mais cedo. Os `contexto.txt` do índice registram `a95a33f`, árvore limpa, limites iguais aos da referência e os mesmos parâmetros de carga. Nas três rodadas, a verificação externa por amostragem não detectou Chrome nem Chromium. As 42 respostas do contrato passaram antes da carga e depois de cada rodada.

A hipótese de ganho com `clientes(lower(email))` fica registrada para um experimento próprio.

## Pool combinado com o índice

A combinação foi medida separadamente, com o índice da H3 e o mesmo pool de 10 conexões da H2. [Hipótese, comparação com a base original e três novas rodadas](experimentos/pool-com-indice.md).

## H4 — Índice dos itens por pedido

- **Decisão e previsão da pessoa.** Criar um índice simples em `itens_pedido(pedido_id)` para localizar os itens pelo pedido. A pessoa espera aumento de requisições por segundo e queda na mediana dos p95 gerais, pois a busca atual examina muitos itens para devolver poucos.
- **Evidência antes da mudança.** A consulta em lote do cliente 7 recebeu cinco IDs e devolveu dez itens. O PostgreSQL fez `Parallel Seq Scan` em `itens_pedido`. Naquela execução, o único índice de `itens_pedido` era o da chave primária em `id`. [Plano antes do índice](diagnostico/lote-itens-sem-indice.txt#L20)
- **Hipótese de trabalho.** Um índice B-tree em `pedido_id` deve dar ao planejador um caminho de acesso mais seletivo para `pedido_id = ANY(...)`, reduzindo os blocos acessados. Esperamos menor p95 na rota de pedidos do cliente, que tem peso de 20% na carga. O impacto no p95 geral depende do peso das outras consultas lentas. Sob carga contínua, o banco pode continuar perto do limite de CPU mesmo com mais vazão.
- **Como medir.** Comparar o plano do cliente 7 e registrar os blocos acessados e o espaço do novo índice. Validar o contrato e executar três rodadas com 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42. Comparar as medianas de vazão, p50 e p95 gerais, p95 da rota, CPU e memória com a [versão com lote, índice de pedidos e pool de 10](experimentos/pool-com-indice.md#resultado-da-combinação). Consultar também a linha de base original.

### Resultado da H4

Mediana de três rodadas por versão. Para CPU e memória, a tabela usa a mediana das médias por rodada.

| Métrica | Base original | Lote + índice de pedidos + pool de 10 | Versão anterior + índice de itens |
| --- | ---: | ---: | ---: |
| Requisições/s | 2,87 | 6,11 | 8,73 |
| p50 geral | 1.299,9 ms | 1.906,7 ms | 1.305,7 ms |
| p95 geral | 21.354,1 ms | 7.596,3 ms | 5.684,8 ms |
| p99 geral | 25.935,8 ms | 11.580,0 ms | 13.448,3 ms |
| p95 de pedidos do cliente | 24.349,4 ms | 7.629,6 ms | 3.958,7 ms |
| Erros HTTP | 0,00% | 0,00% | 0,00% |
| CPU média do banco | 98,5% | 100,2% | 99,6% |
| Memória média do banco | 405,7 MiB | 363,6 MiB | 410,6 MiB |
| CPU média da API | 5,9% | 7,4% | 10,2% |
| Memória média da API | 32,8 MiB | 33,2 MiB | 43,5 MiB |

Arquivos de origem. Base original [B1](resultados/20261117-020419-00-linha-de-base/), [B2](resultados/20261117-020610-00-linha-de-base/), [B3](resultados/20261117-020801-00-linha-de-base/). Referência direta [R1](resultados/20261117-212530-04-pool-10-com-indice/), [R2](resultados/20261117-212701-04-pool-10-com-indice/), [R3](resultados/20261117-212832-04-pool-10-com-indice/). Índice de itens [I1](resultados/20261117-214631-05-indice-itens-pedido/), [I2](resultados/20261117-214801-05-indice-itens-pedido/), [I3](resultados/20261117-214932-05-indice-itens-pedido/). Os números vêm de `resumo.txt` e `recursos.txt`.

Todas as rodadas com o índice de itens tiveram maior vazão (8,56 a 9,05 contra 5,94 a 6,16 req/s) e menor p95 geral (5.503,6 a 6.311,8 ms contra 7.309,6 a 7.701,4 ms). O p95 de pedidos do cliente também caiu nas três rodadas (3.699,2 a 3.982,0 ms contra 7.094,9 a 8.359,3 ms). A mediana do p99 geral subiu e as faixas se sobrepõem. A CPU do PostgreSQL continuou perto do limite durante a carga e a memória média dos dois serviços subiu.

A consulta em lote do cliente 7 encontrou os mesmos dez itens usando os mesmos cinco IDs. O plano trocou `Parallel Seq Scan` por `Index Scan` com `pedido_id = ANY(...)` e usou ordenação incremental. No nó de acesso a `itens_pedido`, o plano sem índice registrou `shared hit=2539 read=7016`. Com o índice, o nó registrou `shared hit=16 read=7`. O índice ocupou 22.003.712 bytes (`21 MB` na saída do PostgreSQL). Os planos foram coletados fora da carga. O teste HTTP usa rotas de leitura, e o custo de manter o índice em escritas fica em aberto. [Plano sem índice](diagnostico/lote-itens-sem-indice.txt#L20) · [Plano e tamanho com índice](diagnostico/lote-itens-com-indice.txt#L12)

O banco com o índice foi criado em um volume isolado, usando os scripts de dados do desafio. A referência foi medida anteriormente. As três rodadas da H4 registraram `c88e3f1`, árvore limpa, os mesmos parâmetros e limites da referência. Nas verificações por amostragem não apareceu Chrome nem Chromium. As 42 respostas do contrato passaram antes e depois da carga em todas as rodadas.

## H5 — Índice composto para pedidos por status

- **Decisão da pessoa.** Testar primeiro um índice B-tree em `pedidos(status, criado_em DESC, id DESC)`. A pessoa escolheu preservar a paginação por número e avaliou que mudar a forma como o cliente usa a API, como no caso da Shopify, não compensa agora. A paginação por cursor ficou como experimento futuro.
- **Evidência antes da mudança.** A página liderou o tempo SQL acumulado. Os planos do SQL atual mostraram varredura em `pedidos` e ordenação em disco nas páginas profundas dos status mais frequentes. [Diagnóstico detalhado](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/blob/f017e80e98f19dc4e741f41ed47fe7eb8f9a73a5/diagnostico/pedidos-por-status/README.md) · [Caso do GitLab](https://docs.gitlab.com/development/database/offset_pagination_optimization/) · [Caso da Shopify](https://shopify.engineering/pagination-relative-cursors).
- **Hipótese e previsão.** O índice pode entregar os registros do status na ordem da consulta, reduzindo ou eliminando a ordenação em disco. Esperamos menor p95 para a rota e possível aumento de req/s e redução de p95 geral. O `OFFSET` ainda precisa avançar pelas entradas anteriores, e a contagem exata pode mudar de plano conforme o status e a visibilidade das linhas.
- **Como medir.** Alterar apenas o índice. Comparar os planos da página e da contagem, medir o espaço ocupado, verificar o contrato e executar três rodadas com 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42. Usar a [H4](#resultado-da-h4) como referência imediata e a linha de base original para o ganho acumulado.

**Base para entender o plano.** Selinger e colegas descrevem como um otimizador baseado em custo compara caminhos de acesso e considera a ordem produzida por cada um. Na H5, essa distinção orienta a leitura dos planos com varredura seguida de ordenação e com acesso pelo índice composto. [Patricia Selinger et al., *Access Path Selection in a Relational Database Management System*, ACM SIGMOD, 1979](https://web.eecs.umich.edu/~michjc/eecs584/Papers/selinger_1979.pdf)

### Resultado da H5

Mediana de três rodadas por versão. CPU e memória médias são as medianas das médias por rodada. O pico na tabela é a maior amostra de memória das três rodadas.

| Métrica | Base original | H4, antes do índice de status | H5, com o índice de status |
| --- | ---: | ---: | ---: |
| Requisições/s | 2,87 | 8,73 | 14,75 |
| p50 geral | 1.299,9 ms | 1.305,7 ms | 813,2 ms |
| p95 geral | 21.354,1 ms | 5.684,8 ms | 3.998,3 ms |
| p99 geral | 25.935,8 ms | 13.448,3 ms | 9.480,2 ms |
| p95 de pedidos por status | 19.588,4 ms | 8.184,2 ms | 4.856,0 ms |
| Erros HTTP | 0,00% | 0,00% | 0,00% |
| CPU média do banco | 98,5% | 99,6% | 100,1% |
| Memória média do banco | 405,7 MiB | 410,6 MiB | 355,5 MiB |
| CPU média da API | 5,9% | 10,2% | 15,2% |
| Memória média da API | 32,8 MiB | 43,5 MiB | 99,8 MiB |
| Maior amostra de memória do banco | 497,8 MiB | 510,8 MiB | 511,4 MiB |
| Maior amostra de memória da API | 39,86 MiB | 60,99 MiB | 118,1 MiB |

Arquivos de origem. Base [B1](resultados/20261117-020419-00-linha-de-base/), [B2](resultados/20261117-020610-00-linha-de-base/), [B3](resultados/20261117-020801-00-linha-de-base/). H4 [A1](resultados/20261117-214631-05-indice-itens-pedido/), [A2](resultados/20261117-214801-05-indice-itens-pedido/), [A3](resultados/20261117-214932-05-indice-itens-pedido/). H5 [D1](resultados/20261118-023254-06-indice-pedidos-status/), [D2](resultados/20261118-023420-06-indice-pedidos-status/), [D3](resultados/20261118-023547-06-indice-pedidos-status/). Vazão e latência vêm de `resumo.txt`. CPU e memória médias vêm de `recursos.txt`. Os picos foram conferidos em `recursos.csv` porque alguns máximos do resumo da H5 ficaram abaixo da média registrada. Os arquivos gerados foram preservados.

As três rodadas da H5 tiveram mais vazão (14,66 a 14,92 contra 8,56 a 9,05 req/s), menor p95 geral (3.756,6 a 4.010,8 contra 5.503,6 a 6.311,8 ms) e menor p95 da rota de pedidos por status (4.854,3 a 4.949,2 contra 7.842,6 a 10.833,1 ms). O banco seguiu próximo do limite de CPU. O maior uso de memória da API ficou em 118,1 MiB e o do banco ficou em 511,4 MiB, perto do limite de 512 MiB.

Os mesmos 21 casos do diagnóstico foram executados fora da carga. Nos quatro status, o plano da primeira página passou a usar `Index Scan` sem `Sort`. Na página 1.000 de `pago`, os blocos temporários gravados passaram de 11.508 para 0. A contagem passou a usar `Index Only Scan` nos quatro status e ainda verifica a visibilidade das linhas. O índice ocupa 22.118.400 bytes (`21 MB` na saída do PostgreSQL). [Planos antes](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/blob/f017e80e98f19dc4e741f41ed47fe7eb8f9a73a5/diagnostico/pedidos-por-status/planos.txt) · [Página de pago com índice](diagnostico/indice-pedidos-status/planos.txt#L550) · [Contagem com índice](diagnostico/indice-pedidos-status/planos.txt#L31)

Houve exceções. Na página 1.000 de `pendente`, o PostgreSQL usou bitmap para localizar os pedidos e ordenou em disco. Para `pago` nas páginas 15.000 e 15.001, o plano escolheu varrer a tabela e ordenar. O índice oferece um caminho mais barato em muitos casos, e o PostgreSQL ainda decide conforme o status e a profundidade. [Plano de pendente](diagnostico/indice-pedidos-status/planos.txt#L1225) · [Plano da página 15.000](diagnostico/indice-pedidos-status/planos.txt#L1398)

A H5 usou um volume isolado criado com os dados do desafio. As três rodadas registram `031b771`, árvore limpa, os mesmos limites e parâmetros da H4. As verificações por amostragem não detectaram Chrome. As 42 respostas do contrato passaram antes e depois de cada rodada. [SQL usado nos planos](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/blob/f017e80e98f19dc4e741f41ed47fe7eb8f9a73a5/diagnostico/pedidos-por-status/planos.sql)

## H6 — Somar antes de consultar o catálogo no top produtos

- **Decisão da pessoa.** Testar a reescrita do SQL. A pessoa deixou a view materializada de lado porque, se o ranking precisar refletir novas vendas assim que forem confirmadas, os totais guardados ficarão defasados entre refreshes. A API do desafio tem rotas de leitura. A atualização imediata é um critério para o cenário com novas vendas, e o experimento preserva a leitura dos dados atuais. [Views materializadas no PostgreSQL 16](https://www.postgresql.org/docs/16/rules-materializedviews.html)
- **Evidência e fonte.** O plano lê os itens, exclui pedidos cancelados e junta o catálogo antes de agrupar. A variante do diagnóstico devolveu os mesmos 50 resultados na mesma ordem e foi mais rápida nas duas execuções isoladas. A Sisense publicou o padrão de agregar por ID antes de buscar nomes em uma consulta de contagem por painel. [Diagnóstico e planos](diagnostico/top-produtos/README.md) · [Sisense](https://www.sisense.com/blog/use-subqueries-to-count-distinct-50x-faster/)
- **Hipótese.** Somar unidades e receita por `produto_id`, limitar o ranking e buscar o catálogo só dos finalistas deve reduzir o p95 de `GET /relatorios/top-produtos`. O banco ainda precisa percorrer os itens elegíveis. O efeito na vazão e no p95 gerais depende da participação da rota na carga e da disputa por CPU no banco.
- **Como medir.** Mudar só o SQL da rota. Validar campos, filtro, limites e ordenação, com receita decrescente e ID ascendente para desempates. Comparar três rodadas com 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42 com a [H5](#resultado-da-h5). Usar a linha de base original como referência acumulada. Conferir também CPU e memória.

### Resultado da H6

Status **aplicada e medida** no commit `be5976d`. A referência direta é a H5. A linha de base original mostra o efeito acumulado.

| Métrica | Base original | H5 | H6 |
| --- | ---: | ---: | ---: |
| Requisições/s | 2,87 | 14,75 | 17,30 |
| p50 geral | 1.299,9 ms | 813,2 ms | 803,5 ms |
| p95 geral | 21.354,1 ms | 3.998,3 ms | 2.905,4 ms |
| p99 geral | 25.935,8 ms | 9.480,2 ms | 7.526,2 ms |
| p95 de top produtos | 25.039,1 ms | 18.274,7 ms | 14.215,6 ms |
| Erros HTTP | 0,00% | 0,00% | 0,00% |
| CPU média do banco | 98,5% | 100,1% | 100,0% |
| Memória média do banco | 405,7 MiB | 355,5 MiB | 296,8 MiB |
| CPU média da API | 5,9% | 15,2% | 17,5% |
| Memória média da API | 32,8 MiB | 99,8 MiB | 106,5 MiB |
| Maior amostra de memória do banco | 497,8 MiB | 511,4 MiB | 510,6 MiB |
| Maior amostra de memória da API | 39,86 MiB | 118,1 MiB | 123,8 MiB |

Medições da base [B1](resultados/20261117-020419-00-linha-de-base/), [B2](resultados/20261117-020610-00-linha-de-base/), [B3](resultados/20261117-020801-00-linha-de-base/). H5 [A1](resultados/20261118-023254-06-indice-pedidos-status/), [A2](resultados/20261118-023420-06-indice-pedidos-status/), [A3](resultados/20261118-023547-06-indice-pedidos-status/). H6 [R1](resultados/20261118-233026-07-top-produtos-agregar-primeiro/), [R2](resultados/20261118-233152-07-top-produtos-agregar-primeiro/), [R3](resultados/20261118-233318-07-top-produtos-agregar-primeiro/). A vazão e as latências vêm de `resumo.txt`. As médias de recursos vêm de `recursos.txt` e os maiores valores de memória foram conferidos em `recursos.csv`.

Todas as rodadas da H6 tiveram maior vazão (17,02 a 17,75 contra 14,66 a 14,92 req/s), p95 geral menor (2.869,6 a 2.914,8 contra 3.756,6 a 4.010,8 ms) e p95 de top produtos menor (12.786,0 a 17.084,9 contra 17.907,9 a 18.319,0 ms). A rota teve 16 a 17 respostas por rodada na H6 e 14 na H5. Por isso a leitura do p95 da rota é sensível a amostras individuais. O banco continuou perto do limite de CPU. A memória média do banco caiu, com pico ainda próximo do limite de 512 MiB, e a memória média da API subiu.

A H6 reutilizou o volume da H5 com os mesmos índices. A referência foi medida mais cedo no mesmo dia. As três rodadas registraram o commit `be5976d`, árvore limpa e os mesmos limites e parâmetros. A amostragem não detectou Chrome ou Chromium. As 42 respostas do contrato passaram antes da carga e após cada rodada.

**Decisão após medir.** A pessoa autora escolheu manter a reescrita depois de conferir o ganho de vazão e a queda no p95. O p50 geral também caiu, de 813,2 ms na H5 para 803,5 ms na H6. [Decisões](docs/decisoes.md#mudanças-integradas)

## H7 — Índice para busca por e-mail

- **Decisão da pessoa.** Priorizar o índice em `lower(email)`, hipótese já discutida na H3. A busca representa 15% da carga. A pessoa espera queda no p50 e no p95 gerais porque o banco repete uma leitura ampla para responder a uma consulta frequente. [Distribuição da carga](carga/teste-carga.js#L44)
- **Evidência e fonte.** Na versão da H6, o plano para um e-mail cadastrado devolveu uma linha após descartar 99.999. O PostgreSQL pode indexar a expressão usada no filtro. O índice não será único, pois o contrato devolve todos os clientes correspondentes em ordem de ID. [Plano sem índice](diagnostico/pos-h6/planos.txt#L83) · [Índices de expressão no PostgreSQL](https://www.postgresql.org/docs/16/indexes-expressional.html)
- **Hipótese de trabalho.** Um B-tree em `clientes(lower(email))` deve reduzir o trabalho na busca e diminuir o p50 e o p95 da rota. A hipótese da pessoa será avaliada pelas medianas gerais e pela vazão. Medir CPU, memória e espaço do índice. Com usuários virtuais fixos, o banco pode continuar perto do limite enquanto atende mais requisições.
- **Como medir.** Adicionar somente o índice, criar um volume isolado com os mesmos dados e verificar as 42 respostas, incluindo e-mails com maiúsculas e ausentes. Comparar três rodadas com a [H6](#resultado-da-h6), com 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42.

### Resultado da H7

Status **aplicada e medida** no commit `58d5f0c`. A comparação direta usa a H6. As latências e os recursos médios são medianas das três rodadas. A linha de base original mostra a evolução acumulada.

| Métrica | Base original | H6 | H7 |
| --- | ---: | ---: | ---: |
| Requisições/s | 2,87 | 17,30 | 19,27 |
| p50 geral | 1.299,9 ms | 803,5 ms | 598,1 ms |
| p95 geral | 21.354,1 ms | 2.905,4 ms | 3.416,2 ms |
| p99 geral | 25.935,8 ms | 7.526,2 ms | 7.256,0 ms |
| p50 de cliente por e-mail | 1.300,3 ms | 988,3 ms | 302,6 ms |
| p95 de cliente por e-mail | 2.540,5 ms | 1.401,0 ms | 880,9 ms |
| Erros HTTP | 0,00% | 0,00% | 0,00% |
| CPU média do banco | 98,5% | 100,0% | 100,3% |
| Memória média do banco | 405,7 MiB | 296,8 MiB | 320,2 MiB |
| CPU média da API | 5,9% | 17,5% | 19,2% |
| Memória média da API | 32,8 MiB | 106,5 MiB | 50,0 MiB |
| Maior amostra de memória do banco | 497,8 MiB | 510,6 MiB | 497,3 MiB |
| Maior amostra de memória da API | 39,86 MiB | 123,8 MiB | 72,24 MiB |

Rodadas da base [B1](resultados/20261117-020419-00-linha-de-base/), [B2](resultados/20261117-020610-00-linha-de-base/), [B3](resultados/20261117-020801-00-linha-de-base/). H6 [A1](resultados/20261118-233026-07-top-produtos-agregar-primeiro/), [A2](resultados/20261118-233152-07-top-produtos-agregar-primeiro/), [A3](resultados/20261118-233318-07-top-produtos-agregar-primeiro/). H7 [R1](resultados/20261119-000113-08-indice-email/), [R2](resultados/20261119-000238-08-indice-email/), [R3](resultados/20261119-000402-08-indice-email/). Latência e vazão vêm de `resumo.txt`. Médias de recursos vêm de `recursos.txt` e os picos de memória foram conferidos em `recursos.csv`.

**A hipótese se confirmou parcialmente.** Todas as rodadas da H7 tiveram maior vazão (18,21 a 20,03 contra 17,02 a 17,75 req/s), p50 geral menor (595,7 a 601,3 contra 800,7 a 804,3 ms) e p95 da busca por e-mail menor (804,1 a 953,0 contra 1.394,6 a 1.473,1 ms). O p95 geral subiu em todas as rodadas (3.200,6 a 3.655,3 contra 2.869,6 a 2.914,8 ms). O banco permaneceu perto do limite de CPU, e a memória média do banco subiu.

O plano usou o índice tanto para o e-mail cadastrado quanto para o ausente. No caso cadastrado, o índice apontou uma linha e o executor acessou um bloco da tabela, em vez de percorrer todos os clientes. O índice ocupa 4.907.008 bytes (4792 kB na saída do PostgreSQL). Os planos foram executados fora da carga e ajudam a explicar o efeito na busca. [Plano da H6](diagnostico/pos-h6/planos.txt#L83) · [Plano e tamanho na H7](diagnostico/indice-clientes-email.txt#L7)

As três rodadas registraram `58d5f0c`, árvore limpa, os mesmos parâmetros da H6 e os mesmos limites de CPU e memória. A H7 usou um volume novo com os mesmos scripts de dados e com o novo índice. A amostragem não detectou Chrome ou Chromium. As 42 respostas do contrato foram iguais antes da carga e após cada rodada.

**Decisão após medir.** A pessoa autorizou integrar os PRs abertos. A H7 foi mantida com o ganho de vazão e de p50 e a piora de p95 registrados. [Decisões](docs/decisoes.md#mudanças-integradas)

## H8 — Agrupar vendas por dia no PostgreSQL

- **Decisão da pessoa.** Retirar a coluna `observacoes` da consulta porque a API descarta seu conteúdo. A pessoa escolheu calcular os totais em SQL e deixar o índice de data para um teste separado. A escolha reduz o volume enviado ao Node e evita introduzir uma estrutura de armazenamento e manutenção para este experimento.
- **Evidência.** Na semana do diagnóstico, a consulta de detalhes devolveu 12.945 linhas, com 3.551.664 bytes só no campo de observações. A versão agrupada devolveu sete linhas. O índice de data ajudou o banco a localizar os pedidos do período em um plano isolado. [Comparação dos planos](https://github.com/Lhferraaz/t4h-estagio-pesquisa-ferraz/blob/76bf5bb770923f8039b29dbf3d8af158b8517fe5/diagnostico/vendas-por-dia/README.md)
- **Hipótese.** Agrupar por dia no PostgreSQL deve reduzir o p95 de vendas por dia e o trabalho de leitura e agregação no Node. Esperamos melhora na vazão e no p95 geral se a redução de tráfego compensar o trabalho de contar pedidos distintos e somar no banco. O efeito sob concorrência e na memória dos dois serviços será medido. [Agregações no PostgreSQL](https://www.postgresql.org/docs/16/functions-aggregate.html)
- **Como medir.** Alterar a consulta e a formatação do JSON da rota. Preservar pedidos distintos, unidades, receita, intervalo inclusivo, filtro de cancelados, dias com itens e ordem crescente. Confirmar o contrato e comparar com a [H7](#resultado-da-h7) em três rodadas com 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42.

### Resultado da H8

Status **aplicada e medida** no commit `2d9d1d3`. A referência direta é a H7. A linha de base original mostra a evolução acumulada. As métricas abaixo são medianas das três rodadas, salvo os maiores valores amostrados de memória.

| Métrica | Base original | H7 | H8 |
| --- | ---: | ---: | ---: |
| Requisições/s | 2,87 | 19,27 | 23,19 |
| p50 geral | 1.299,9 ms | 598,1 ms | 492,6 ms |
| p95 geral | 21.354,1 ms | 3.416,2 ms | 2.402,7 ms |
| p99 geral | 25.935,8 ms | 7.256,0 ms | 9.623,8 ms |
| p50 de vendas por dia | 6.614,3 ms | 2.604,7 ms | 1.494,9 ms |
| p95 de vendas por dia | 12.543,8 ms | 5.819,2 ms | 2.809,0 ms |
| p95 de pedidos por status | 19.588,4 ms | 2.986,0 ms | 6.847,2 ms |
| Erros HTTP | 0,00% | 0,00% | 0,00% |
| CPU média do banco | 98,5% | 100,3% | 100,0% |
| Memória média do banco | 405,7 MiB | 320,2 MiB | 298,8 MiB |
| CPU média da API | 5,9% | 19,2% | 3,0% |
| Memória média da API | 32,8 MiB | 50,0 MiB | 78,7 MiB |
| Maior amostra de memória do banco | 497,8 MiB | 497,3 MiB | 492,8 MiB |
| Maior amostra de memória da API | 39,86 MiB | 72,24 MiB | 80,05 MiB |

Rodadas da base [B1](resultados/20261117-020419-00-linha-de-base/), [B2](resultados/20261117-020610-00-linha-de-base/), [B3](resultados/20261117-020801-00-linha-de-base/). H7 [A1](resultados/20261119-000113-08-indice-email/), [A2](resultados/20261119-000238-08-indice-email/), [A3](resultados/20261119-000402-08-indice-email/). H8 [R1](resultados/20261119-030803-09-vendas-por-dia-sql/), [R2](resultados/20261119-030925-09-vendas-por-dia-sql/), [R3](resultados/20261119-031049-09-vendas-por-dia-sql/). As latências e a vazão vêm de `resumo.txt`. As médias de recursos vêm de `recursos.txt` e os picos de memória foram conferidos em `recursos.csv`.

**A hipótese principal ganhou força.** Todas as rodadas da H8 tiveram mais vazão (22,78 a 23,55 contra 18,21 a 20,03 req/s), menor p95 geral (2.293,6 a 2.908,6 contra 3.200,6 a 3.655,3 ms) e menor p95 no relatório (2.298,0 a 3.067,0 contra 5.302,5 a 6.018,8 ms). Na H8, a rota de vendas por dia recebeu 104 a 108 chamadas por rodada.

**Contrapartidas.** O p99 geral subiu nas três rodadas (7.997,0 a 9.898,8 contra 6.767,7 a 7.531,8 ms). Também subiu o p95 de pedidos por status. A atribuição da piora na cauda exige outra coleta. O banco continuou perto do limite de CPU. A memória média do banco caiu e a da API subiu. A CPU média da API caiu.

O plano da consulta aplicada devolveu sete linhas para sete dias. As 42 respostas do contrato passaram antes da carga e após cada rodada. A resposta de 31 dias também bateu com os totais calculados a partir dos itens individuais, e um período sem vendas devolveu lista vazia. [Plano da H8](diagnostico/vendas-por-dia-h8.txt#L6)

A H8 reaproveitou o volume da H7. As medições foram feitas mais tarde, com os mesmos parâmetros e limites e com a árvore limpa no commit medido. A amostragem durante as rodadas não detectou Chrome ou Chromium.

**Decisão após medir.** A pessoa autorizou integrar a H8. Foram mantidos os ganhos de vazão e de p95 geral e do relatório. A piora do p99 geral e do p95 de pedidos por status segue registrada como contrapartida da medição. [Decisões](docs/decisoes.md#mudanças-integradas)

## H9 — Índice simples para a contagem de pedidos por status

- **Origem.** A pessoa pediu uma revisão final e autorizou testar mais uma melhoria. A IA propôs investigar pedidos por status e, após a coleta da H8, priorizou a contagem exata. Ela respondeu por 27,8% do tempo SQL acumulado nessa rodada, frente a 7,5% da consulta da página. [Diagnóstico](diagnostico/pos-h8/README.md)
- **Hipótese.** Um B-tree simples em `pedidos(status)` permite contar pelo índice menor, com menos acesso a blocos. O índice composto continua disponível para atender ao filtro e à ordem da página. O custo adicional é espaço em disco e manutenção do novo índice nas escritas. [Planos locais](diagnostico/pos-h8/planos.txt) · [Deduplicação em B-tree no PostgreSQL 16](https://www.postgresql.org/docs/16/btree-implementation.html#BTREE-DEDUPLICATION)
- **Previsão antes da carga.** Esperamos menor p95 de pedidos por status e possível ganho de vazão. O p95 geral depende de como a mudança afeta a espera das demais rotas. O ganho observado em planos isolados pode diminuir durante a carga ou com alterações frequentes na tabela.
- **Como medir.** Comparar três rodadas da H8 com três rodadas após adicionar somente o índice. Iniciar um volume novo para cada versão com os mesmos dados e verificar o contrato antes e após a carga. Manter 20 usuários virtuais, 60 s, aquecimento de 15 s, semente 42 e os mesmos limites dos contêineres. Comparar vazão, p50/p95/p99 gerais, p95 de pedidos por status, erros, CPU e memória.

### Resultado da H9

Status **aplicada, medida e integrada**. O código foi medido no commit `1dc06e9`. A referência direta é uma nova série da H8 no commit `4d18769`, sem mudança no código da API ou no banco em relação à H8 original. Cada série começou com um volume novo, com os mesmos dados, parâmetros e limites. A amostragem não detectou Chrome ou Chromium. O verificador comparou as 42 respostas antes e depois de cada série de carga e após cada rodada.

| Métrica | H8 de referência | H9 com índice |
| --- | ---: | ---: |
| Requisições/s | 21,55 | 22,92 |
| p50 geral | 594,5 ms | 494,7 ms |
| p95 geral | 2.635,8 ms | 2.598,6 ms |
| p99 geral | 7.425,8 ms | 7.287,1 ms |
| p50 de pedidos por status | 1.099,5 ms | 803,8 ms |
| p95 de pedidos por status | 4.914,5 ms | 4.733,7 ms |
| p99 de pedidos por status | 8.073,7 ms | 8.581,3 ms |
| Erros HTTP | 0,00% | 0,00% |
| CPU média do banco | 100,3% | 99,7% |
| Memória média do banco | 358,5 MiB | 373,0 MiB |
| CPU média da API | 3,3% | 3,4% |
| Memória média da API | 26,7 MiB | 26,9 MiB |
| Maior amostra de memória do banco | 508,7 MiB | 508,3 MiB |
| Maior amostra de memória da API | 28,34 MiB | 28,18 MiB |

Os valores são medianas de três rodadas. As duas últimas linhas mostram o maior pico amostrado no CSV. A vazão foi de 16,22, 21,55 e 21,56 req/s na referência e de 17,50, 22,92 e 23,43 req/s com o índice. As seis rodadas foram sequenciais, com as três da referência primeiro. A primeira rodada de cada série teve menos vazão que as seguintes. As rodadas originais da H8 seguem registradas com 23,19 req/s de mediana e foram realizadas em outro horário, com um volume reaproveitado.

Referência [R1](resultados/20261119-204957-10-h8-referencia-contagem/) · [R2](resultados/20261119-205121-10-h8-referencia-contagem/) · [R3](resultados/20261119-205247-10-h8-referencia-contagem/). H9 [I1](resultados/20261119-205521-11-indice-contagem-status/) · [I2](resultados/20261119-205646-11-indice-contagem-status/) · [I3](resultados/20261119-205811-11-indice-contagem-status/). [Ambiente e verificações antes das séries](diagnostico/pos-h8/medicoes.txt).

**Conclusão.** A hipótese ganhou força para vazão e p50. O p95 de pedidos por status teve mediana menor e faixas sobrepostas. O p95 geral mudou pouco frente à variação entre rodadas, e o p99 da rota piorou na mediana. O índice ocupou 3.514.368 bytes também no banco da H9. A memória média do banco subiu e as duas séries tiveram picos próximos ao limite de 512 MiB. A carga contém só leituras, então o custo de manter o índice nas escritas continua em aberto. [Índice no banco da H9](diagnostico/pos-h8/indice-h9-ativo.txt)

**Decisão após medir.** A pessoa decidiu incorporar o índice pelo ganho de vazão e pela queda do p50, com a piora do p99 da rota registrada. [Decisões](docs/decisoes.md#mudanças-integradas)

## H10 — Reduzir o limite de memória da API

- **Origem.** A pessoa pediu testar uma versão com menor custo de memória. A IA sugeriu começar pelo limite da API e testar depois o tamanho do pool, conforme a proposta anterior da pessoa.
- **Hipótese.** A API deve atender à mesma carga com limite de 128 MiB. O maior pico amostrado foi 28,18 MiB na H9 e 80,05 MiB na H8 original. Reduzir o limite da API de 256 para 128 MiB leva o total dos limites de API e banco de 768 para 640 MiB. O limite configura a capacidade disponível. O consumo observado vem da coleta. [Resultado da H9](#resultado-da-h9) · [Limites de memória no Docker](https://docs.docker.com/engine/containers/resource_constraints/#limit-a-containers-access-to-memory)
- **Previsão antes da carga.** Esperamos contrato mantido, zero encerramentos por falta de memória e vazão e latência dentro da variação das séries. Medir erros e eventos de pressão, porque o pico amostrado pelo Docker pode ficar abaixo do pico de cobrança do cgroup.
- **Como medir.** Comparar com a H9 de 256 MiB e pool de 10 conexões. Usar banco com os mesmos índices e dados, volume novo, 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42. Conferir todo o contrato, fazer três rodadas e registrar uso de memória, vazão, p50, p95 e eventos de memória.

### Resultado da H10

Status **aplicada, medida e integrada**. O código foi medido no commit `6968756`. A comparação usa as três rodadas da H9 da mesma noite como referência. As duas séries começaram com volumes novos e usaram a mesma carga. A amostragem não detectou Chrome ou Chromium.

| Métrica | H9, API 256 MiB | H10, API 128 MiB |
| --- | ---: | ---: |
| Vazão | 22,92 req/s | 22,61 req/s |
| p50 geral | 494,7 ms | 495,8 ms |
| p95 geral | 2.598,6 ms | 2.796,1 ms |
| p99 geral | 7.287,1 ms | 7.659,4 ms |
| Erros HTTP | 0,00% | 0,00% |
| CPU média da API | 3,4% | 3,4% |
| Memória média da API | 26,9 MiB | 27,0 MiB |
| Maior amostra de memória da API | 28,18 MiB | 28,19 MiB |
| CPU média do banco | 99,7% | 100,1% |
| Memória média do banco | 373,0 MiB | 322,9 MiB |
| Maior amostra de memória do banco | 508,3 MiB | 501,1 MiB |

Os valores são medianas de três rodadas, exceto os maiores picos do CSV. A API preservou as 42 respostas, teve zero eventos de limite máximo no cgroup e zero encerramentos por falta de memória. O pico da API observado no cgroup foi de 34.160.640 bytes. O uso médio e o pico amostrado da API ficaram próximos aos da H9, com um teto configurado 128 MiB menor. A vazão variou pouco na mediana. O p95 subiu, com sobreposição no intervalo das três rodadas. O resultado sustenta a viabilidade de 128 MiB nessa carga. [Contadores de memória](diagnostico/testes-de-memoria/12-api-128-mib-memoria.txt)

[Referência H9](#resultado-da-h9) · [A1](resultados/20261119-210917-12-api-128-mib/) · [A2](resultados/20261119-211041-12-api-128-mib/) · [A3](resultados/20261119-211206-12-api-128-mib/).

**Decisão após medir.** A pessoa decidiu manter o limite de 128 MiB na API para reduzir o orçamento de memória. A variação do p95 geral ficou registrada. [Decisões](docs/decisoes.md#mudanças-integradas)

## H11 — Reduzir o pool do PostgreSQL para quatro conexões

- **Origem.** A pessoa propôs testar o pool com quatro conexões e retomou a proposta ao pedir uma versão com menor custo de memória. A IA sugeriu medir a redução do pool em uma série separada do ajuste do limite da API.
- **Hipótese.** Reduzir o máximo do `pg.Pool` de 10 para 4 pode reduzir a memória do PostgreSQL ao limitar quantas consultas da API executam ao mesmo tempo. Parte da espera pode passar para a fila do pool. O efeito sobre vazão e latência precisa ser medido. [Dimensionamento do pool](https://node-postgres.com/guides/pool-sizing)
- **Previsão antes da carga.** Esperamos redução da memória média ou do pico do banco. Vamos observar se o p95 sobe ou se a vazão cai, especialmente nas rotas leves que passam pelo mesmo pool.
- **Como medir.** Usar a H10 como referência com o limite de 128 MiB na API. Alterar somente `max` do pool para 4. Criar o volume com os mesmos dados e índices, manter PostgreSQL em 1 CPU e 512 MiB e rodar três vezes com a mesma carga. Conferir o contrato, os percentis, os recursos e os eventos de memória.

### Resultado da H11

Status **testada e adiada**. O código experimental foi medido no commit `6354ae5`. A H10 com dez conexões é a referência direta. Cada série começou com um volume novo e a mesma configuração do PostgreSQL. Mantivemos o limite da API em 128 MiB. A amostragem não detectou Chrome ou Chromium.

| Métrica | H10, pool de 10 | H11, pool de 4 |
| --- | ---: | ---: |
| Vazão | 22,61 req/s | 25,32 req/s |
| p50 geral | 495,8 ms | 600,6 ms |
| p95 geral | 2.796,1 ms | 2.196,9 ms |
| p99 geral | 7.659,4 ms | 3.796,9 ms |
| p95 de pedidos por status | 4.428,8 ms | 2.610,3 ms |
| p95 de vendas por dia | 3.768,8 ms | 1.803,8 ms |
| p95 de top produtos | 13.402,1 ms | 4.893,5 ms |
| Erros HTTP | 0,00% | 0,00% |
| CPU média do banco | 100,1% | 100,6% |
| Memória média do banco | 322,9 MiB | 353,5 MiB |
| Maior amostra de memória do banco | 501,1 MiB | 509,8 MiB |
| CPU média da API | 3,4% | 3,3% |
| Memória média da API | 27,0 MiB | 26,9 MiB |
| Maior amostra de memória da API | 28,19 MiB | 28,26 MiB |

Os valores são medianas de três rodadas, exceto os maiores picos do CSV. O contrato manteve as 42 respostas antes e depois da carga. Os p95 e p99 gerais das três rodadas com quatro conexões ficaram abaixo de todos os valores da H10. A melhora foi mais visível nos dois relatórios. A mediana geral de resposta subiu. A hipótese de menos disputa entre consultas longas e mais espera por conexão ajuda a explicar o padrão. A coleta não mediu o tempo em fila no pool.

O objetivo de reduzir a memória observada do banco ficou sem apoio nas médias e picos amostrados. O banco ainda chegou perto dos 512 MiB. O contador `max` do banco, que indica tentativas de ultrapassar o limite do cgroup, aumentou 12.795 vezes na H10 e 2.996 na H11 entre a checagem inicial e a checagem ao fim da terceira rodada. O swap do banco também estava menor na checagem final. A janela inclui aquecimentos e verificações de contrato, além da carga. Não houve reinícios ou encerramentos por falta de memória. [Série com dez](diagnostico/testes-de-memoria/12-api-128-mib-memoria.txt) · [Série com quatro](diagnostico/testes-de-memoria/13-pool-quatro-memoria.txt) · [Contadores do cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html#memory-interface-files)

**Decisão após medir.** A pessoa decidiu adiar o pool de quatro e manter dez conexões. Embora a H11 tenha melhorado o p95 e o p99 gerais, o p50 subiu nas cinco rotas que somam 90% do peso previsto na carga. A H11 fica registrada como experimento. [Decisões](docs/decisoes.md#mudanças-integradas)

[Referência H10](#resultado-da-h10) · [P1](resultados/20261119-211433-13-pool-quatro/) · [P2](resultados/20261119-211556-13-pool-quatro/) · [P3](resultados/20261119-211719-13-pool-quatro/).

## H12 — Redistribuir a cota de CPU dos contêineres

- **Origem.** A pessoa pediu avaliar o Docker e autorizou testar a redistribuição. Na coleta da H10, o PostgreSQL atingiu a cota em 627 de 632 períodos ativos e a API em zero de 527. Uma segunda coleta deu 620 de 626 para o banco e zero de 512 para a API. [Diagnóstico dos contêineres](diagnostico/containers-h10/README.md) · [Segunda coleta](diagnostico/containers-h10/repeticao/deltas.txt)
- **Hipótese.** Alterar o teto do PostgreSQL de 1,00 para 1,25 CPU e o da API de 0,50 para 0,25 CPU libera mais CPU para as consultas dentro do teto somado de 1,5 CPU. Manter o pool de dez e os limites de memória da H10. A API pode ter restrição na cota menor. [Limites de CPU no Docker](https://docs.docker.com/engine/containers/resource_constraints/#cpu)
- **Previsão e critério.** Esperamos ganho de vazão ou redução do p95 geral, com p50 das rotas mais frequentes dentro da variação da referência. Conferir se a API passou a atingir a cota com frequência, se o p99 mudou e quanto de CPU e memória cada contêiner usou. Um banco mais rápido pode continuar atingindo a cota com usuários virtuais em carga contínua.
- **Como medir.** Comparar três rodadas novas da H10 com três rodadas da distribuição proposta. Cada série começa com um volume novo com os mesmos dados e índices. Usar Chrome fechado, 20 usuários virtuais, 60 s de carga, 15 s de aquecimento e semente 42. Conferir o contrato antes da carga e após cada rodada. Ler `cpu.stat` antes e depois de cada execução do script oficial.

### Resultado da H12

Status **aplicada, medida e integrada**. A alteração foi medida no commit `8fc2fba`. A referência é uma nova série da H10 no commit `f08a8aa`. Os bancos foram criados em volumes novos a partir dos mesmos scripts. Cada série usou Chrome fechado, 20 usuários virtuais, 60 s de carga, aquecimento de 15 s e semente 42. As 42 respostas do contrato passaram antes de cada série e após cada rodada.

| Métrica | H10, banco 1,00 e API 0,50 CPU | H12, banco 1,25 e API 0,25 CPU |
| --- | ---: | ---: |
| Vazão | 23,75 req/s | 26,27 req/s |
| p50 geral | 499,8 ms | 402,5 ms |
| p95 geral | 2.409,5 ms | 2.399,6 ms |
| p99 geral | 6.604,8 ms | 6.580,4 ms |
| p50 de cliente por ID | 204,6 ms | 197,5 ms |
| p50 de cliente por e-mail | 206,5 ms | 200,5 ms |
| p50 de pedidos do cliente | 795,1 ms | 605,2 ms |
| p50 de pedidos por status | 898,5 ms | 794,5 ms |
| p50 de busca de produtos | 497,1 ms | 391,7 ms |
| p95 de pedidos por status | 4.416,2 ms | 5.426,9 ms |
| p99 de pedidos por status | 8.706,2 ms | 10.235,0 ms |
| Erros HTTP | 0,00% | 0,00% |
| CPU média do banco | 99,8% | 125,0% |
| Memória média do banco | 325,1 MiB | 367,1 MiB |
| Maior amostra de memória do banco | 506,2 MiB | 494,7 MiB |
| CPU média da API | 3,3% | 3,6% |
| Memória média da API | 27,2 MiB | 26,9 MiB |
| Maior amostra de memória da API | 28,92 MiB | 28,20 MiB |

Os valores são medianas de três rodadas, exceto os maiores picos amostrados de memória nos CSVs. A vazão da H12 ficou entre 24,31 e 26,70 req/s, acima de toda a faixa da H10, de 18,15 a 23,80 req/s. As medianas de p50 das cinco rotas mais frequentes caíram. O p95 e o p99 gerais ficaram próximos e as faixas entre rodadas se sobrepuseram. O p95 e o p99 de pedidos por status subiram na mediana.

O teto total permaneceu em 1,5 CPU, e o consumo medido do banco aumentou. O banco ainda atingiu a cota na maior parte dos períodos ativos. Na API, os contadores subiram em 11 de 1.962 períodos na H12 e em 1 de 1.979 na H10. A janela inclui o aquecimento e o contrato ao fim da carga. Nenhum contêiner registrou encerramento por falta de memória. A memória média do banco subiu. [Cotas aplicadas e contadores](diagnostico/redistribuicao-cpu/README.md)

**Conclusão.** A hipótese ganhou força pelo aumento de vazão e pela queda no p50, com a mesma soma das cotas. A pessoa decidiu adotar a redistribuição pelo ganho de vazão e de p50. A piora da cauda de pedidos por status ficou registrada. [Decisões](docs/decisoes.md#mudanças-integradas)

Referência [R1](resultados/20261119-220254-14-h10-referencia-cpu/) · [R2](resultados/20261119-220418-14-h10-referencia-cpu/) · [R3](resultados/20261119-220543-14-h10-referencia-cpu/). H12 [C1](resultados/20261119-220806-15-redistribuir-cpu/) · [C2](resultados/20261119-220929-15-redistribuir-cpu/) · [C3](resultados/20261119-221053-15-redistribuir-cpu/).

## H13 — Desabilitar o paralelismo dentro das consultas

- **Origem.** A pessoa propôs desabilitar as consultas paralelas após a H12 e autorizou testar. Na H12, o banco continuou próximo da cota de 1,25 CPU e o p95 de pedidos por status subiu de 4.416,2 para 5.426,9 ms. [Resultado da H12](#resultado-da-h12)
- **Hipótese.** Definir `max_parallel_workers_per_gather=0` reduz o número de processos disputando a cota do banco em cada consulta. As conexões do pool ainda podem executar consultas diferentes ao mesmo tempo. [Configuração do PostgreSQL 16](https://www.postgresql.org/docs/16/runtime-config-resource.html#GUC-MAX-PARALLEL-WORKERS-PER-GATHER)
- **Previsão e critério.** Esperamos menor p95 para pedidos por status. A contagem isolada foi mais rápida sem workers no diagnóstico da H10, enquanto top produtos passou a gravar temporários quando rodou sem paralelismo. A mudança precisa preservar vazão e p50 das rotas mais usadas. Um ganho em status pode custar latência e trabalho em disco nos relatórios. [Planos isolados](diagnostico/containers-h10/planos.txt)
- **Como medir.** Comparar três rodadas novas da H12, com o padrão de dois workers, com três rodadas sem workers por consulta. Cada série começa em um volume novo com os mesmos dados e índices. Manter cota de CPU, memória e pool da H12. Usar Chrome fechado, 20 usuários virtuais, 60 s de carga, aquecimento de 15 s e semente 42. Conferir as 42 respostas, req/s, p50, p95, p99, CPU e memória. Ler `pg_stat_database` e `cpu.stat` antes e depois de cada execução do script oficial.
