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
| Itens dos pedidos em lote, sem índices ou pool novos | [diagnóstico](diagnostico/leitura-inicial.md), [PostgreSQL: `ANY`](https://www.postgresql.org/docs/16/functions-comparisons.html) e [node-postgres: parâmetros](https://node-postgres.com/features/queries) | Aplicada e medida | 2,87 req/s; p95 geral 21.354,1 ms; p95 da rota 24.349,4 ms | 4,38 req/s; p95 geral 12.394,1 ms; p95 da rota 11.501,6 ms | Antes: [B1](resultados/20261117-020419-00-linha-de-base/), [B2](resultados/20261117-020610-00-linha-de-base/), [B3](resultados/20261117-020801-00-linha-de-base/). Depois: [L1](resultados/20261117-025739-01-itens-em-lote/), [L2](resultados/20261117-025923-01-itens-em-lote/), [L3](resultados/20261117-030107-01-itens-em-lote/). | Nesta carga, as três execuções do lote tiveram mais req/s e p95 geral menor que as três da base. O contrato foi mantido. O banco permaneceu próximo do limite de CPU; redução de custo absoluto não foi demonstrada. |

| Recurso durante a carga | Antes (mediana das médias) | Depois (mediana das médias) |
| --- | ---: | ---: |
| CPU do banco | 98,5% | 99,7% |
| Memória do banco | 405,7 MiB | 393,2 MiB |
| CPU da API | 5,9% | 7,0% |
| Memória da API | 32,8 MiB | 34,5 MiB |

Os limites dos containers continuaram iguais. Cada `contexto.txt` registra 20 VUs, 60s, semente 42, o commit `38fd459` para o depois e `arquivos alterados sem commit: 0`; cada `contrato.txt` termina em “Contrato mantido”. A comparação usa os arquivos `resumo.txt` e `recursos.txt` das pastas acima. Não medimos custo monetário nem isolamos quanto do ganho veio de menos consultas, menos conexões ou uma única varredura de itens por requisição.
