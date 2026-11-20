\pset pager off

BEGIN READ ONLY;

SET LOCAL statement_timeout = '30s';

PREPARE vendas(date, date) AS
SELECT to_char(p.criado_em::date, 'YYYY-MM-DD') AS dia,
            count(DISTINCT p.id) AS pedidos,
            sum(i.quantidade) AS itens,
            sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos
       FROM pedidos p
       JOIN itens_pedido i ON i.pedido_id = p.id
      WHERE p.criado_em::date BETWEEN $1 AND $2
        AND p.status <> 'cancelado'
      GROUP BY p.criado_em::date
      ORDER BY p.criado_em::date;

PREPARE ranking(integer) AS
SELECT pr.id, pr.nome, pr.categoria, ranking.unidades, ranking.receita_centavos
       FROM (
         SELECT i.produto_id,
                sum(i.quantidade) AS unidades,
                sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
           FROM itens_pedido i
           JOIN pedidos p ON p.id = i.pedido_id
          WHERE p.status <> 'cancelado'
          GROUP BY i.produto_id
          ORDER BY receita_centavos DESC, i.produto_id
          LIMIT $1
       ) AS ranking
       JOIN produtos pr ON pr.id = ranking.produto_id
      ORDER BY ranking.receita_centavos DESC, pr.id;

PREPARE contagem(text) AS
SELECT count(*) FROM pedidos WHERE status = $1;

SET LOCAL max_parallel_workers_per_gather = 2;

\echo VENDAS_WORKERS_2

EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE vendas('2024-01-01', '2024-01-07');

\echo RANKING_WORKERS_2

EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE ranking(10);

\echo CONTAGEM_WORKERS_2

EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('pago');

SET LOCAL max_parallel_workers_per_gather = 0;

\echo VENDAS_WORKERS_0

EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE vendas('2024-01-01', '2024-01-07');

\echo RANKING_WORKERS_0

EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE ranking(10);

\echo CONTAGEM_WORKERS_0

EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE contagem('pago');

ROLLBACK;
