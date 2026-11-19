BEGIN READ ONLY;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL plan_cache_mode = force_custom_plan;

\echo CONTEXTO
SELECT current_database(), version();
SHOW shared_preload_libraries;
SHOW work_mem;
SHOW max_parallel_workers_per_gather;
SHOW block_size;

\echo ESTADO_DE_PEDIDOS
SELECT status, count(*) AS pedidos FROM pedidos GROUP BY status ORDER BY status;
SELECT pg_relation_size('public.pedidos') AS bytes_tabela,
       relpages, relallvisible FROM pg_class WHERE oid = 'public.pedidos'::regclass;
SELECT attname, avg_width FROM pg_stats
WHERE schemaname = 'public' AND tablename = 'pedidos' ORDER BY attname;
SELECT indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'pedidos' ORDER BY indexname;

PREPARE total_status(text) AS
SELECT count(*) AS total FROM pedidos WHERE status = $1;

PREPARE pagina_atual(text, integer, bigint) AS
SELECT * FROM pedidos WHERE status = $1
ORDER BY criado_em DESC, id DESC LIMIT $2 OFFSET $3;

PREPARE pagina_projecao(text, integer, bigint) AS
SELECT id, cliente_id, status, criado_em FROM pedidos WHERE status = $1
ORDER BY criado_em DESC, id DESC LIMIT $2 OFFSET $3;

\echo CASO|contagem|pago|-
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE total_status('pago');

\echo CASO|contagem|entregue|-
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE total_status('entregue');

\echo CASO|contagem|cancelado|-
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE total_status('cancelado');

\echo CASO|contagem|pendente|-
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE total_status('pendente');

\echo CASO|pagina|pago|1
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('pago', 20, 0);

\echo CASO|pagina|pago|500
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('pago', 20, 9980);

\echo CASO|pagina|pago|1000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('pago', 20, 19980);

\echo CASO|pagina|entregue|1
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('entregue', 20, 0);

\echo CASO|pagina|entregue|500
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('entregue', 20, 9980);

\echo CASO|pagina|entregue|1000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('entregue', 20, 19980);

\echo CASO|pagina|cancelado|1
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('cancelado', 20, 0);

\echo CASO|pagina|cancelado|500
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('cancelado', 20, 9980);

\echo CASO|pagina|cancelado|1000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('cancelado', 20, 19980);

\echo CASO|pagina|pendente|1
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('pendente', 20, 0);

\echo CASO|pagina|pendente|500
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('pendente', 20, 9980);

\echo CASO|pagina|pendente|1000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('pendente', 20, 19980);

\echo CASO|pagina|pago|15000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('pago', 20, 299980);

\echo CASO|pagina|pago|15001
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_atual('pago', 20, 300000);

\echo CASO|projecao|pendente|1000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_projecao('pendente', 20, 19980);

\echo CASO|projecao|pago|1000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_projecao('pago', 20, 19980);

\echo CASO|projecao|pago|15000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF, SETTINGS, FORMAT JSON) EXECUTE pagina_projecao('pago', 20, 299980);

ROLLBACK;
