# Experimentos

## H1 — Itens dos pedidos em lote

- **Decisão da pessoa, antes da mudança:** testar primeiro a busca em lote dos itens. A consulta única com todos os joins fica como alternativa para testar depois, por ter maior risco de alterar o contrato; uma única ida ao banco não garante menor trabalho total.
- **Hipótese de trabalho, formulada a partir dessa decisão:** buscar de uma vez os itens dos pedidos de um cliente, junto com os nomes dos produtos, deve reduzir as consultas repetidas da rota `GET /clientes/:id/pedidos` e melhorar seu tempo de resposta sob carga sem mudar status, campos, valores ou ordem da resposta.
- **Previsão antes da medição:** para o cliente 7 usado no diagnóstico, o fluxo de 17 consultas SQL passa a 3 (verificação do cliente, pedidos e lote de itens com produtos). Espera-se redução do p95 dessa rota e possível melhora do resultado geral; o tamanho do efeito e o consumo de CPU e memória ainda são desconhecidos. Sem índices novos, a consulta em lote ainda pode varrer `itens_pedido`.
- **Evidência e leitura da ideia:** [diagnóstico local](diagnostico/leitura-inicial.md), [comparação com `ANY` na documentação do PostgreSQL 16](https://www.postgresql.org/docs/16/functions-comparisons.html) e [consultas parametrizadas no node-postgres](https://node-postgres.com/features/queries).
- **Como julgar:** contrato mantido; três medições com o mesmo rótulo e parâmetros da [linha de base](resultados/20261117-020419-00-linha-de-base/contexto.txt); comparação das medianas gerais e da rota, com CPU e memória dos serviços. Os valores de antes e depois serão preenchidos somente depois da medição.
- **Status:** hipótese registrada; mudança ainda não aplicada nem medida.
