\set ON_ERROR_STOP on
BEGIN;
SET LOCAL TIME ZONE 'UTC';
SET LOCAL statement_timeout = '60s';
SET LOCAL plan_cache_mode = force_custom_plan;

\echo CONTEXTO
SELECT version();
SELECT indexname FROM pg_indexes WHERE tablename IN ('pedidos', 'itens_pedido') ORDER BY indexname;

PREPARE detalhes(date, date) AS
SELECT p.id AS pedido_id, p.criado_em, i.quantidade, i.preco_unitario_centavos
  FROM pedidos p
  JOIN itens_pedido i ON i.pedido_id = p.id
 WHERE p.criado_em::date BETWEEN $1 AND $2 AND p.status <> 'cancelado';

PREPARE totais(date, date) AS
SELECT p.criado_em::date AS dia, count(DISTINCT p.id) AS pedidos,
       sum(i.quantidade) AS itens,
       sum(i.quantidade::bigint * i.preco_unitario_centavos) AS receita_centavos
  FROM pedidos p
  JOIN itens_pedido i ON i.pedido_id = p.id
 WHERE p.criado_em::date BETWEEN $1 AND $2 AND p.status <> 'cancelado'
 GROUP BY p.criado_em::date
 ORDER BY dia;

\echo TEXTO_TRANSFERIDO_PELA_CONSULTA_ATUAL
WITH periodos(dias, inicio, fim) AS (
    VALUES (7, DATE '2024-01-01', DATE '2024-01-07'),
           (31, DATE '2024-01-01', DATE '2024-01-31')
)
SELECT dias, count(*) AS linhas, sum(octet_length(p.observacoes)) AS bytes_de_observacoes
  FROM periodos
  JOIN pedidos p ON p.criado_em::date BETWEEN inicio AND fim
  JOIN itens_pedido i ON i.pedido_id = p.id
 WHERE p.status <> 'cancelado'
 GROUP BY dias ORDER BY dias;

\echo BASE_SEM_OBSERVACOES_7_DIAS
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE detalhes('2024-01-01', '2024-01-07');
\echo BASE_SEM_OBSERVACOES_31_DIAS
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE detalhes('2024-01-01', '2024-01-31');

\echo AGRUPAR_NO_SQL_7_DIAS
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE totais('2024-01-01', '2024-01-07');
\echo AGRUPAR_NO_SQL_31_DIAS
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE totais('2024-01-01', '2024-01-31');

CREATE INDEX vendas_dia_diag_criado_em_date_idx ON pedidos ((criado_em::date));
ANALYZE pedidos;
\echo TAMANHO_INDICE_DE_TESTE
SELECT pg_relation_size('vendas_dia_diag_criado_em_date_idx') AS bytes,
       pg_size_pretty(pg_relation_size('vendas_dia_diag_criado_em_date_idx')) AS tamanho;

\echo INDICE_DE_DATA_7_DIAS
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE detalhes('2024-01-01', '2024-01-07');
\echo INDICE_DE_DATA_31_DIAS
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE detalhes('2024-01-01', '2024-01-31');

\echo AGRUPAR_COM_INDICE_7_DIAS
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE totais('2024-01-01', '2024-01-07');
\echo AGRUPAR_COM_INDICE_31_DIAS
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) EXECUTE totais('2024-01-01', '2024-01-31');

ROLLBACK;

SELECT to_regclass('vendas_dia_diag_criado_em_date_idx') IS NULL AS indice_de_teste_desfeito;
