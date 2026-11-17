# Leitura inicial dos planos SQL

Esta é uma análise preliminar produzida com apoio de IA, ainda sem mudança de performance. Os comandos reproduzíveis estão em [explain-consultas.sql](explain-consultas.sql) e a saída integral em [explain-consultas.txt](explain-consultas.txt). O estado do PostgreSQL está em [estado-postgres.sql](estado-postgres.sql) e [estado-postgres.txt](estado-postgres.txt). As consultas foram executadas fora do teste de carga e nenhuma tabela foi alterada.

## Como ler estes números

`EXPLAIN (ANALYZE, BUFFERS)` executa cada `SELECT` e mostra o plano escolhido e os blocos acessados. Seus tempos servem para investigar o trabalho dentro do PostgreSQL nesta execução isolada. Eles não incluem envio das linhas ao cliente e têm custo de instrumentação; portanto, não são diretamente comparáveis à latência HTTP da linha de base. Ver [documentação do PostgreSQL 16 sobre EXPLAIN](https://www.postgresql.org/docs/16/using-explain.html#USING-EXPLAIN-ANALYZE).

## O que os planos mostram

| Consulta | Evidência observada | Leitura preliminar |
| --- | --- | --- |
| Cliente por ID | `Index Scan using clientes_pkey` | A busca pela chave primária usa índice. |
| Cliente por e-mail | `Seq Scan on clientes`; 99.999 linhas removidas pelo filtro para devolver 1 | O predicado `lower(email)` não encontrou um índice aplicável na estrutura original. |
| Pedidos de um cliente | `Parallel Seq Scan on pedidos`; 5 linhas devolvidas para o cliente 7 | O banco percorre a tabela de pedidos para localizar os de um cliente. |
| Itens de um pedido | `Parallel Seq Scan on itens_pedido`; 2 linhas devolvidas para o pedido 1 | A consulta feita dentro do loop percorre a tabela de itens. |
| Pedidos por status | A contagem usa `Parallel Seq Scan on pedidos`; a página 1000 usa `Sort Method: external merge` com arquivo temporário | Contagem e paginação fazem leitura ampla; a ordenação desta página não coube na memória disponível para o plano. |
| Busca de produtos | `Seq Scan on produtos` e ordenação para `LIMIT 20` | A busca com `ILIKE '%cadeira%'` percorre os produtos no estado original. |
| Vendas por dia | Varreduras de `pedidos` e `itens_pedido`; 12.945 linhas saem do SQL no intervalo consultado | A API recebe as linhas detalhadas e faz a agregação por dia no JavaScript. |
| Top produtos | Varreduras de `pedidos` e `itens_pedido`, joins e agregação antes do `LIMIT 10` | O relatório processa muitos itens para produzir a lista final. |

Para o cliente 7, a consulta de diagnóstico encontrou 5 pedidos e 10 itens. Pelo fluxo de `api/src/rotas.js`, essa requisição executa uma consulta para verificar o cliente, uma para listar os pedidos, uma por pedido para os itens e uma por item para o produto: 17 chamadas SQL para esse exemplo. `api/src/db.js` cria e encerra uma conexão em cada chamada. Essa contagem descreve o código e o dado consultado; não é uma medição de latência.

## `pg_stat_statements`

O módulo está disponível, mas `shared_preload_libraries` está vazio e a extensão não foi criada neste banco. Por isso não há histórico de `pg_stat_statements` para a linha de base. A [documentação do PostgreSQL 16](https://www.postgresql.org/docs/16/pgstatstatements.html) exige carregá-lo na inicialização do servidor, reiniciá-lo e criar a extensão no banco. Ativá-lo agora mudaria a configuração observada; não foi feito nesta investigação.

## Próxima decisão

A linha de base em `resultados/` mostra o desempenho sob carga; estes planos apontam possíveis causas dentro do banco e o código mostra chamadas repetidas. Ainda não isolamos o efeito de nenhuma delas. A próxima mudança deve partir de uma hipótese específica, com previsão escrita antes da alteração, contrato preservado e três medições comparadas com a linha de base.
