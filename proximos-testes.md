# Próximos testes

## Consulta única com joins para os pedidos de um cliente

- **Status:** pesquisada, teste futuro. A pessoa escolheu testar primeiro a busca em lote e mencionou esta alternativa como possível experimento posterior.
- **Origem:** [diagnóstico das consultas atuais](diagnostico/leitura-inicial.md) e [documentação do PostgreSQL 16 sobre joins](https://www.postgresql.org/docs/16/queries-table-expressions.html).
- **Hipótese a formular antes do teste:** uma consulta que parte de `clientes` e une pedidos, itens e produtos pode reduzir ainda mais as idas ao banco em relação ao lote. Isso não garante menor tempo nem menor uso de CPU, porque o banco terá de executar os joins e a API receberá linhas com dados repetidos de cada pedido.
- **Como testar:** partir de um estado medido, alterar só a rota, preservar `404`, listas vazias, campos, valores e ordem; passar no verificador de contrato e fazer três medições com os mesmos parâmetros. Comparar as medianas gerais, da rota e de CPU e memória com o estado escolhido como “antes”.
- **O que é necessário:** tempo para implementar a reconstrução do JSON e revisar os casos de cliente inexistente, pedido sem itens e ordenação. Não exige serviço novo. Nenhum ganho foi medido para esta alternativa.
