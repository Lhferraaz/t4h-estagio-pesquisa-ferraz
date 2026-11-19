\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '30s';
SET LOCAL plan_cache_mode = force_custom_plan;

\echo CONTEXTO
SELECT version();
SHOW work_mem;
SELECT tablename, indexname FROM pg_indexes
 WHERE schemaname = 'public' ORDER BY tablename, indexname;

\echo VENDAS_LINHAS_ATUAIS
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT p.id AS pedido_id, p.criado_em, p.observacoes,
       i.quantidade, i.preco_unitario_centavos
  FROM pedidos p
  JOIN itens_pedido i ON i.pedido_id = p.id
 WHERE p.criado_em::date BETWEEN DATE '2024-01-01' AND DATE '2024-01-07'
   AND p.status <> 'cancelado';

\echo VENDAS_AGRUPADAS_NO_SQL
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT p.criado_em::date AS dia,
       count(DISTINCT p.id) AS pedidos, sum(i.quantidade) AS itens,
       sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos
  FROM pedidos p
  JOIN itens_pedido i ON i.pedido_id = p.id
 WHERE p.criado_em::date BETWEEN DATE '2024-01-01' AND DATE '2024-01-07'
   AND p.status <> 'cancelado'
 GROUP BY p.criado_em::date
 ORDER BY dia;

\echo EMAIL_CADASTRADO
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT * FROM clientes
 WHERE lower(email) = lower('cliente3@exemplo.com')
 ORDER BY id;

\echo BUSCA_TERMO_COMUM
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT * FROM produtos
 WHERE nome ILIKE '%cadeira%'
 ORDER BY nome, id LIMIT 20;

\echo BUSCA_TERMO_AUSENTE
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT * FROM produtos
 WHERE nome ILIKE '%inexistente%'
 ORDER BY nome, id LIMIT 20;

\echo PEDIDOS_CONTAGEM_PAGO
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT count(*) AS total FROM pedidos WHERE status = 'pago';

\echo PEDIDOS_PAGINA_1
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT * FROM pedidos WHERE status = 'pago'
 ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 0;

\echo PEDIDOS_PAGINA_1000
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT * FROM pedidos WHERE status = 'pago'
 ORDER BY criado_em DESC, id DESC LIMIT 20 OFFSET 19980;

COMMIT;
