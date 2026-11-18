# Pool de conexões com o índice de pedidos por cliente

## Hipótese antes da combinação

- **Pedido da pessoa.** Testar juntos a busca em lote, o índice em `pedidos(cliente_id)` e o pool previamente testado com 10 conexões. A pessoa pediu para reconferir a vazão da linha de base original.
- **Hipótese de trabalho.** O índice reduz o trabalho de localizar pedidos. O `pg.Pool` reutiliza conexões e limita a 10 as consultas concorrentes por processo. A combinação pode processar mais requisições ou reduzir o p95 geral em relação à versão com lote e índice. A latência mediana e a memória da API podem subir, como no teste isolado do pool.
- **Como medir.** Manter a implementação do pool de 10 conexões e o banco com o índice já aplicado. Validar o contrato e medir três vezes com 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42. Usar a H3 (lote e índice) como comparação direta e manter as variantes anteriores para contextualizar os ganhos.

## Resultado da combinação

Cada coluna usa a mediana de três rodadas. Para CPU e memória, são as medianas das médias registradas em cada rodada.

| Métrica | Base original | Lote | Lote + pool | Lote + índice | Lote + índice + pool |
| --- | ---: | ---: | ---: | ---: | ---: |
| Requisições/s | 2,87 | 4,57 | 5,14 | 5,46 | 6,11 |
| p50 geral | 1.299,9 ms | 1.302,7 ms | 2.194,6 ms | 1.302,0 ms | 1.906,7 ms |
| p95 geral | 21.354,1 ms | 12.015,7 ms | 8.788,3 ms | 11.520,0 ms | 7.596,3 ms |
| p95 de pedidos do cliente | 24.349,4 ms | 11.299,7 ms | 9.337,8 ms | 7.901,9 ms | 7.629,6 ms |
| Erros HTTP | 0,00% | 0,00% | 0,00% | 0,00% | 0,00% |
| CPU média do banco | 98,5% | 99,8% | 99,6% | 99,5% | 100,2% |
| Memória média do banco | 405,7 MiB | 412,4 MiB | 379,4 MiB | 397,5 MiB | 363,6 MiB |
| CPU média da API | 5,9% | 6,5% | 6,4% | 7,6% | 7,4% |
| Memória média da API | 32,8 MiB | 35,1 MiB | 86,3 MiB | 37,4 MiB | 33,2 MiB |

Os três `resumo.txt` da base original registram 3,03, 2,87, 2,84 req/s, com mediana de 2,87. A comparação de 4,57 para 5,46 req/s usou o lote como referência para testar o índice, pois o lote já estava na `main`.

Arquivos de origem. Base [B1](../resultados/20261117-020419-00-linha-de-base/), [B2](../resultados/20261117-020610-00-linha-de-base/), [B3](../resultados/20261117-020801-00-linha-de-base/). Lote [L1](../resultados/20261117-030752-01-itens-em-lote-chrome-fechado/), [L2](../resultados/20261117-030935-01-itens-em-lote-chrome-fechado/), [L3](../resultados/20261117-031120-01-itens-em-lote-chrome-fechado/). Lote e pool [P1](../resultados/20261117-204120-02-pool-10-chrome-fechado/), [P2](../resultados/20261117-204251-02-pool-10-chrome-fechado/), [P3](../resultados/20261117-204421-02-pool-10-chrome-fechado/). Lote e índice [I1](../resultados/20261117-210544-03-indice-pedidos-cliente/), [I2](../resultados/20261117-210713-03-indice-pedidos-cliente/), [I3](../resultados/20261117-210845-03-indice-pedidos-cliente/). Combinação [C1](../resultados/20261117-212530-04-pool-10-com-indice/), [C2](../resultados/20261117-212701-04-pool-10-com-indice/), [C3](../resultados/20261117-212832-04-pool-10-com-indice/). Os números vêm de `resumo.txt` e `recursos.txt`.

Em relação ao lote com índice, as três rodadas da combinação entregaram maior vazão (5,94 a 6,16 contra 5,45 a 5,62 req/s) e menor p95 geral (7.309,6 a 7.701,4 ms contra 10.325,1 a 11.860,3 ms). O p50 geral foi maior nas três rodadas (1.903,2 a 2.000,9 ms contra 1.298,0 a 1.400,6 ms). O p95 do cliente por ID subiu de 501,4 para 1.900,0 ms. O banco continuou perto do limite de CPU. A medição inclui o reuso de conexões e o limite de 10. A espera no pool é uma hipótese para a piora em consultas rápidas.

As 42 respostas passaram no contrato antes da carga e após cada rodada. As três rodadas registraram o commit `3c74954`, árvore limpa, 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42. O teste usou o mesmo container PostgreSQL e o mesmo índice da H3. Apenas a API foi reconstruída e as séries foram feitas em sequência, com o aquecimento do script. Por pedido da pessoa, as tentativas anteriores com processos do Chrome foram descartadas da comparação. Uma checagem a cada cinco segundos, além do início e do fim, não detectou Chrome nem Chromium nas três rodadas refeitas.
