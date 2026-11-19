SELECT clock_timestamp() AS capturado_em, stats_reset, dealloc
FROM pg_stat_statements_info;

WITH normalizadas AS (
    SELECT s.*, regexp_replace(btrim(s.query), '[[:space:]]+', ' ', 'g') AS sql
    FROM pg_stat_statements AS s
    WHERE s.toplevel
      AND s.dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
      AND s.userid = (SELECT oid FROM pg_roles WHERE rolname = current_user)
      AND s.query ~* '^[[:space:]]*SELECT[[:space:]]'
),
consultas AS (
    SELECT *,
           CASE
               WHEN sql LIKE 'SELECT * FROM clientes WHERE id = %' THEN 'clientes por id'
               WHEN sql LIKE 'SELECT * FROM clientes WHERE lower(email) = %' THEN 'clientes por email'
               WHEN sql LIKE 'SELECT * FROM pedidos WHERE cliente_id = %' THEN 'pedidos do cliente'
               WHEN sql LIKE 'SELECT i.pedido_id, i.produto_id, pr.nome%' THEN 'itens dos pedidos em lote'
               WHEN sql LIKE 'SELECT count(*) AS total FROM pedidos WHERE status = %' THEN 'contagem de pedidos por status'
               WHEN sql LIKE 'SELECT * FROM pedidos WHERE status = %' THEN 'página de pedidos por status'
               WHEN sql LIKE 'SELECT * FROM produtos WHERE nome ILIKE %' THEN 'busca de produtos'
               WHEN sql LIKE 'SELECT p.id AS pedido_id, p.criado_em%' THEN 'vendas por dia'
               WHEN sql LIKE 'SELECT pr.id, pr.nome, pr.categoria, sum(i.quantidade)%' THEN 'top produtos'
               ELSE 'sem classificação'
           END AS consulta
    FROM normalizadas
)
SELECT consulta, calls,
       round(total_exec_time::numeric, 1) AS total_ms,
       round((100.0 * total_exec_time / nullif(sum(total_exec_time) OVER (), 0))::numeric, 1) AS pct_tempo_sql,
       round(mean_exec_time::numeric, 1) AS media_ms,
       round(max_exec_time::numeric, 1) AS max_ms,
       rows, shared_blks_hit, shared_blks_read, temp_blks_read, temp_blks_written,
       queryid, sql
FROM consultas
ORDER BY total_exec_time DESC, queryid;
