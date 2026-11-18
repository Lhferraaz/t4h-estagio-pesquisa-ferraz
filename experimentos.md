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
