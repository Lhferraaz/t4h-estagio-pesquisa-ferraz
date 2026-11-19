BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL plan_cache_mode = force_custom_plan;

\echo CONTEXTO
SELECT current_database(), version();
SHOW work_mem;
SHOW max_parallel_workers_per_gather;
SHOW shared_preload_libraries;

\echo ITENS_NO_RANKING
SELECT count(*) AS itens_total,
       count(*) FILTER (WHERE p.status <> 'cancelado') AS itens_elegiveis
FROM itens_pedido i
JOIN pedidos p ON p.id = i.pedido_id;

PREPARE top_atual(integer) AS
SELECT pr.id, pr.nome, pr.categoria,
       sum(i.quantidade) AS unidades,
       sum(i.quantidade * i.preco_unitario_centavos) AS receita_centavos
FROM itens_pedido i
JOIN pedidos p ON p.id = i.pedido_id
JOIN produtos pr ON pr.id = i.produto_id
WHERE p.status <> 'cancelado'
GROUP BY pr.id, pr.nome, pr.categoria
ORDER BY receita_centavos DESC, pr.id
LIMIT $1;

PREPARE top_somar_primeiro(integer) AS
SELECT pr.id, pr.nome, pr.categoria, ranking.unidades, ranking.receita_centavos
FROM (
    SELECT i.produto_id, sum(i.quantidade) AS unidades,
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

\echo CASO|atual|1
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE top_atual(10);

\echo CASO|somar_primeiro|1
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE top_somar_primeiro(10);

\echo CASO|somar_primeiro|2
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE top_somar_primeiro(10);

\echo CASO|atual|2
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE top_atual(10);

\echo RESULTADO|atual
EXECUTE top_atual(50);
\echo RESULTADO|somar_primeiro
EXECUTE top_somar_primeiro(50);
ROLLBACK;
